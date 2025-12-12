import express from "express";
import sql from "mssql";

const app = express();

// Azure Web App sets this from Key Vault automatically
const connectionString = process.env.SQL_CONNECTION_STRING;

// Basic middleware
app.use(express.json());

// Lightweight request logging (no extra dependency)
app.use((req, res, next) => {
    const start = Date.now();
    res.on("finish", () => {
        const ms = Date.now() - start;
        console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${ms}ms`);
    });
    next();
});

// Health endpoint (checks app + DB)
app.get("/health", async (req, res) => {
    try {
        if (!connectionString) {
            return res.status(500).json({
                status: "unhealthy",
                reason: "SQL_CONNECTION_STRING is missing"
            });
        }

        const pool = await sql.connect(connectionString);
        await pool.request().query("SELECT 1 AS ok;");

        return res.status(200).json({ status: "ok" });
    } catch (err) {
        console.error("Health check failed:", err);
        return res.status(500).json({ status: "unhealthy", reason: "DB check failed" });
    }
});

app.get("/", async (req, res) => {
    try {
        if (!connectionString) {
            console.error("SQL_CONNECTION_STRING is missing");
            return res.status(500).send("Configuration error.");
        }

        const pool = await sql.connect(connectionString);

        // Step 1: get total number of rows
        const countResult = await pool.request().query("SELECT COUNT(*) AS total FROM Quotes");
        const total = countResult.recordset[0]?.total ?? 0;

        if (total === 0) {
            return res.send("No quotes found in database.");
        }

        // Step 2: pick a random offset
        const randomOffset = Math.floor(Math.random() * total);

        // Step 3: fetch exactly one quote using OFFSET/FETCH
        const quoteResult = await pool.request()
            .input("offset", sql.Int, randomOffset)
            .query(`
        SELECT Id, Author, Text
        FROM Quotes
        ORDER BY Id
        OFFSET @offset ROWS
        FETCH NEXT 1 ROWS ONLY;
      `);

        const quote = quoteResult.recordset[0];

        if (!quote) {
            return res.status(500).send("Error retrieving quote.");
        }

        res.send(`
      <div style="font-family: Arial; margin: 50px;">
        <h1>Random Quote</h1>
        <p style="font-size: 1.2rem;">"${quote.Text}"</p>
        <p><strong>- ${quote.Author}</strong></p>
      </div>
    `);
    } catch (err) {
        console.error("Error retrieving quote:", err);
        res.status(500).send("Error retrieving quote.");
    }
});

// Global error handler (extra safety)
app.use((err, req, res, next) => {
    console.error("Unhandled error:", err);
    res.status(500).send("Internal server error.");
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`App running on port ${port}`));
