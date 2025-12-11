import express from "express";
import sql from "mssql";

const app = express();

// Azure Web App sets this from Key Vault automatically
const connectionString = process.env.SQL_CONNECTION_STRING;

app.get("/", async (req, res) => {
    try {
        const pool = await sql.connect(connectionString);
        const result = await pool.request().query("SELECT TOP 1 * FROM Quotes ORDER BY NEWID()");
        const quote = result.recordset[0];

        res.send(`
      <div style="font-family: Arial; margin: 50px;">
        <h1>Random Quote</h1>
        <p style="font-size: 1.2rem;">"${quote.Text}"</p>
        <p><strong>- ${quote.Author}</strong></p>
      </div>
    `);
    } catch (err) {
        console.error(err);
        res.status(500).send("Error retrieving quote.");
    }
});

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`App running on port ${port}`));
