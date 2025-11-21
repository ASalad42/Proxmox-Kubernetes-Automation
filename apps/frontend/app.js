const express = require("express");
const fetch = (...args) => import("node-fetch").then(({ default: fetch }) => fetch(...args));

const app = express();
const port = process.env.PORT || 3000;
const BACKEND_URL = process.env.BACKEND_URL || "http://backend-service.homelab.svc.cluster.local";

app.use(express.urlencoded({ extended: true }));

app.get("/", async (req, res) => {
  try {
    // Fetch all messages from backend
    const response = await fetch(`${BACKEND_URL}/messages`);
    const messages = await response.json();

    const messageList = messages
      .map((m) => `<li>${m.content} <small>(${new Date(m.created_at).toLocaleString()})</small></li>`)
      .join("");

    res.send(`
      <html>
        <head>
          <title>Homelab K8 Frontend</title>
        </head>
        <body style="font-family: Arial; margin: 20px;">
          <h1>Frontend UI</h1>
          <p>This connects to the backend service and PostgreSQL.</p>

          <h2>Add a Message</h2>
          <form method="POST" action="/add">
            <input type="text" name="content" placeholder="Enter a message" required />
            <button type="submit">Submit</button>
          </form>

          <h2>Messages from DB:</h2>
          <ul>${messageList || "<li>No messages yet</li>"}</ul>
        </body>
      </html>
    `);
  } catch (err) {
    console.error(err);
    res.send("<p>Error loading messages from backend.</p>");
  }
});

// POST /add — handle form submission
app.post("/add", async (req, res) => {
  const { content } = req.body;
  try {
    await fetch(`${BACKEND_URL}/messages`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content }),
    });
  } catch (err) {
    console.error("Error sending to backend:", err);
  }
  res.redirect("/");
});

app.listen(port, () => {
  console.log(`🎨 Frontend running on port ${port}`);
});
