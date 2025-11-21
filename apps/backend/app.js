const express = require("express");
const { Pool } = require("pg");
const cors = require("cors");

const app = express();
const port = process.env.PORT || 3000;

app.use(express.json());
app.use(cors());

// PostgreSQL connection pool
const pool = new Pool({
  host: process.env.PGHOST,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
  database: process.env.PGDATABASE,
  port: 5432,
});

// Initialize DB: create messages table if it doesn't exist
async function initDB() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS messages (
        id SERIAL PRIMARY KEY,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log("✅ Table 'messages' is ready");
  } catch (err) {
    console.error("❌ Error initializing DB:", err);
  } finally {
    client.release();
  }
}

app.get("/", (req, res) => {
  res.send("✅ Backend is running and connected to PostgreSQL.");
});

// Get all messages
app.get("/messages", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM messages ORDER BY id DESC;");
    res.json(result.rows);
  } catch (err) {
    console.error(err);
    res.status(500).send("Error fetching messages");
  }
});

// Add a new message
app.post("/messages", async (req, res) => {
  const { content } = req.body;
  if (!content) return res.status(400).send("Missing 'content' field");
  try {
    await pool.query("INSERT INTO messages (content) VALUES ($1)", [content]);
    res.status(201).send("Message added!");
  } catch (err) {
    console.error(err);
    res.status(500).send("Error inserting message");
  }
});

app.listen(port, async () => {
  await initDB();
  console.log(`🚀 Backend running on port ${port}`);
});
