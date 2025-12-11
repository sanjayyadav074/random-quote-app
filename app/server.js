import express from "express";
import sql from "mssql";

const app = express();

// Azure Web App sets this from Key Vault automatically
const connectionString = process.env.SQL_CONNECTION_STRING;

app.get("/", async (req, res) => {
    try {
        const pool = await sql.connect(connectionString);

        // Step 1: get total number of rows
        const countResult = await pool.request().query("SELECT COUNT(*) AS total FROM Quotes");
        const total = countResult.recordset[0].total;

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
