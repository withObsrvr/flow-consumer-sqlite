package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"github.com/withObsrvr/pluginapi"
)

type SQLiteConsumer struct {
	db     *sql.DB
	dbPath string
	tables map[string]bool // Track which tables have been created
}

func (c *SQLiteConsumer) Name() string {
	return "flow/consumer/sqlite"
}

func (c *SQLiteConsumer) Version() string {
	return "1.0.0"
}

func (c *SQLiteConsumer) Type() pluginapi.PluginType {
	return pluginapi.ConsumerPlugin
}

func (c *SQLiteConsumer) Initialize(config map[string]interface{}) error {
	dbPath, ok := config["db_path"].(string)
	if !ok {
		dbPath = "flow_data.db"
	}

	// Ensure the directory exists
	dbDir := filepath.Dir(dbPath)
	if dbDir != "." && dbDir != "" {
		if err := os.MkdirAll(dbDir, 0755); err != nil {
			return fmt.Errorf("failed to create database directory %s: %w", dbDir, err)
		}
	}

	// Check if the database file exists
	_, err := os.Stat(dbPath)
	if err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to check database file: %w", err)
	}

	// SQLite will create the database file if it doesn't exist
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return err
	}

	// Test the connection and create the database if needed
	if err := db.Ping(); err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	c.db = db
	c.dbPath = dbPath
	c.tables = make(map[string]bool)

	log.Printf("SQLite consumer initialized with database: %s", dbPath)

	// Create a metadata table to track information about the database
	_, err = c.db.Exec(`
	CREATE TABLE IF NOT EXISTS flow_metadata (
		key TEXT PRIMARY KEY,
		value TEXT,
		updated_at TEXT
	)
	`)
	if err != nil {
		return fmt.Errorf("failed to create metadata table: %w", err)
	}

	// Record database creation/connection time
	_, err = c.db.Exec(`
	INSERT OR REPLACE INTO flow_metadata (key, value, updated_at)
	VALUES ('last_connection', ?, ?)
	`, time.Now().Format(time.RFC3339), time.Now().Format(time.RFC3339))
	if err != nil {
		log.Printf("Warning: Failed to record connection time: %v", err)
	}

	return nil
}

func (c *SQLiteConsumer) Process(ctx context.Context, msg pluginapi.Message) error {
	// Determine the data type from metadata
	dataType := "unknown"
	if typeVal, ok := msg.Metadata["data_type"].(string); ok {
		dataType = typeVal
	} else {
		// Try to infer data type from other metadata
		if _, ok := msg.Metadata["ledger_sequence"]; ok {
			dataType = "latest_ledger"
		} else if _, ok := msg.Metadata["account_id"]; ok {
			dataType = "account"
		}
	}

	log.Printf("Processing data of type: %s", dataType)

	// Convert payload to JSON if it's not already
	var jsonData []byte
	switch payload := msg.Payload.(type) {
	case []byte:
		jsonData = payload
	case string:
		jsonData = []byte(payload)
	default:
		var err error
		jsonData, err = json.Marshal(payload)
		if err != nil {
			return fmt.Errorf("failed to marshal payload: %w", err)
		}
	}

	// Parse the JSON data
	var data map[string]interface{}
	if err := json.Unmarshal(jsonData, &data); err != nil {
		return fmt.Errorf("failed to unmarshal JSON: %w", err)
	}

	// Create table name from data type
	tableName := strings.ReplaceAll(dataType, "-", "_")
	tableName = strings.ReplaceAll(tableName, "/", "_")

	// Check if we need to create the table
	if !c.tables[tableName] {
		// Generate CREATE TABLE statement dynamically based on the data
		columns := make([]string, 0, len(data))
		for key, value := range data {
			columnName := strings.ReplaceAll(key, "-", "_")
			columnType := "TEXT"

			switch value.(type) {
			case float64, int, int64:
				columnType = "NUMERIC"
			case bool:
				columnType = "BOOLEAN"
			}

			columns = append(columns, fmt.Sprintf("%s %s", columnName, columnType))
		}

		// Add a primary key if we can identify one
		primaryKey := ""

		// Try to find a primary key field
		for _, candidate := range []string{"id", "account_id", "sequence", "hash"} {
			if _, ok := data[candidate]; ok {
				primaryKey = fmt.Sprintf(", PRIMARY KEY(%s)", candidate)
				break
			}
		}

		createTableSQL := fmt.Sprintf("CREATE TABLE IF NOT EXISTS %s (%s%s)",
			tableName, strings.Join(columns, ", "), primaryKey)

		_, err := c.db.Exec(createTableSQL)
		if err != nil {
			return fmt.Errorf("failed to create table %s: %w", tableName, err)
		}

		c.tables[tableName] = true
		log.Printf("Created table %s for data type %s", tableName, dataType)
	}

	// Generate INSERT statement dynamically
	columns := make([]string, 0, len(data))
	placeholders := make([]string, 0, len(data))
	values := make([]interface{}, 0, len(data))

	for key, value := range data {
		columnName := strings.ReplaceAll(key, "-", "_")
		columns = append(columns, columnName)
		placeholders = append(placeholders, "?")
		values = append(values, value)
	}

	insertSQL := fmt.Sprintf("INSERT OR REPLACE INTO %s (%s) VALUES (%s)",
		tableName, strings.Join(columns, ", "), strings.Join(placeholders, ", "))

	_, err := c.db.Exec(insertSQL, values...)
	if err != nil {
		return fmt.Errorf("failed to insert into %s: %w", tableName, err)
	}

	return nil
}

func (c *SQLiteConsumer) Close() error {
	if c.db != nil {
		return c.db.Close()
	}
	return nil
}

// GetSchemaDefinition returns an empty string since we don't hardcode schemas
func (c *SQLiteConsumer) GetSchemaDefinition() string {
	return ""
}

// GetQueryDefinitions returns an empty string since we don't hardcode queries
func (c *SQLiteConsumer) GetQueryDefinitions() string {
	return ""
}

// Export New function
func New() pluginapi.Plugin {
	return &SQLiteConsumer{}
}
