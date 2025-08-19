package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/spf13/cobra"
)

func main() {
	if err := newRootCommand().Execute(); err != nil {
		os.Exit(1)
	}
}

func newRootCommand() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "ochami-fru",
		Short: "A service to gather FRU inventory.",
		Run: func(cmd *cobra.Command, args []string) {
			startServer()
		},
	}
	return cmd
}

func startServer() {
	smdHost := getEnv("SMD_HOST", "smd") // Default to 'smd' if not set
	log.Printf("Starting FRU Inventory API server, connecting to SMD at: %s", smdHost)

	http.HandleFunc("/inventory", inventoryHandler)

	port := getEnv("API_SERVER_PORT", ":8080")
	log.Printf("Server listening on %s", port)

	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

func inventoryHandler(w http.ResponseWriter, r *http.Request) {
	inventory := map[string]interface{}{
		"FRUs": []map[string]string{
			{"name": "GPU-A1", "type": "GPU", "status": "OK"},
			{"name": "CPU-0", "type": "CPU", "status": "OK"},
		},
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(inventory); err != nil {
		log.Printf("Error encoding JSON response: %v", err)
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
