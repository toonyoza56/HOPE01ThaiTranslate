#!/usr/bin/env node
/**
 * Translate selected extracted strings with the OpenAI Responses API.
 *
 * Example:
 *   node tools/translate-openai.mjs --name th-013 --category item_desc --chunk 24
 *
 * It writes translations/src/<name>.txt.  Convert it to the build format with:
 *   powershell -ExecutionPolicy Bypass -File tools/import-batch.ps1 -Name <name>
 *
 * The API key is read only from OPENAI_API_KEY; it is never written to disk.
 */

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const ROOT = path.resolve(import.meta.dirname, "..");
const MODEL = "gpt-5.6-luna";

function argument(name, fallback = undefined) {
  const at = process.argv.indexOf(`--${name}`);
  return at === -1 ? fallback : process.argv[at + 1];
}

function parseCsv(text) {
  const rows = [];
  let row = [], value = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') { value += '"'; i++; }
      else if (char === '"') quoted = false;
      else value += char;
    } else if (char === '"') quoted = true;
    else if (char === ",") { row.push(value); value = ""; }
    else if (char === "\n") { row.push(value.replace(/\r$/, "")); rows.push(row); row = []; value = ""; }
    else value += char;
  }
  if (value || row.length) { row.push(value.replace(/\r$/, "")); rows.push(row); }
  const [header, ...data] = rows;
  return data.filter(r => r.some(Boolean)).map(r => Object.fromEntries(
    header.map((name, i) => [name.replace(/^\uFEFF/, ""), r[i] ?? ""])
  ));
}

function getOutputText(response) {
  if (typeof response.output_text === "string") return response.output_text;
  return response.output?.flatMap(item => item.content ?? [])
    .filter(content => content.type === "output_text")
    .map(content => content.text).join("") ?? "";
}

function countEscapedNewlines(value) {
  return (value.match(/\\n/g) ?? []).length;
}

function requiredTerms(row) {
  return row.keep_terms.split("|").map(term => term.trim())
    .filter(term => term && !term.endsWith("?"));
}

function validate(row, thai) {
  if (!thai || /[\r\n]/.test(thai)) {
    throw new Error(`${row.id}: translation must be a single non-empty line`);
  }
  if (countEscapedNewlines(row.english) !== countEscapedNewlines(thai)) {
    throw new Error(`${row.id}: expected ${countEscapedNewlines(row.english)} literal \\n markers`);
  }
  for (const term of requiredTerms(row)) {
    if (!thai.includes(term)) throw new Error(`${row.id}: required game term missing: ${term}`);
  }
  for (const tag of row.english.match(/\[\/?color=[^\]]+\]|\[\/?color\]/g) ?? []) {
    if (!thai.includes(tag)) throw new Error(`${row.id}: markup tag missing: ${tag}`);
  }
}

const name = argument("name");
const categories = (argument("category", "") ?? "").split(",").map(x => x.trim()).filter(Boolean);
const requestedIds = new Set((argument("id", "") ?? "").split(",").map(x => x.trim()).filter(Boolean));
const chunkSize = Number(argument("chunk", "24"));
const maxBatches = Number(argument("max-batches", "Infinity"));
if (!name || !categories.length || !Number.isInteger(chunkSize) || chunkSize < 1 || chunkSize > 50
  || (!(maxBatches === Infinity) && (!Number.isInteger(maxBatches) || maxBatches < 1))) {
  console.error("Usage: node tools/translate-openai.mjs --name th-013 --category item_desc[,script] [--chunk 24] [--max-batches 1]");
  process.exit(2);
}
if (!process.env.OPENAI_API_KEY) {
  console.error("OPENAI_API_KEY is not configured.");
  process.exit(2);
}

const rows = parseCsv(fs.readFileSync(path.join(ROOT, "work", "strings.csv"), "utf8"));
const outputPath = path.join(ROOT, "translations", "src", `${name}.txt`);
const done = fs.existsSync(outputPath)
  ? new Set(fs.readFileSync(outputPath, "utf8").split(/\r?\n/).filter(Boolean)
      .filter(line => !line.startsWith("#")).map(line => line.slice(0, line.indexOf("|")).trim()))
  : new Set();
const selected = rows.filter(row => row.translate === "yes" && categories.includes(row.category) && !row.thai && !done.has(row.id)
  && (!requestedIds.size || requestedIds.has(row.id)));

const style = fs.readFileSync(path.join(ROOT, "translations", "STYLE.md"), "utf8");
const instructions = `You are translating HOPE 01, a dark sci-fi game, from English into natural Thai.\n\n${style}\n\nReturn exactly one Thai translation for every input row. Preserve literal \\n markers, all numbers, punctuation needed by the original, and Construct tags such as [color=...]...[/color]. The REQUIRED_VERBATIM_TERMS field is a hard constraint: copy every listed string exactly, including spelling, plurality, capitals, spaces, and punctuation; never translate, shorten, or omit it. Do not add polite particles. Do not translate item names, NPC names, room/place names, or upgrade names. Keep the output concise but do not omit meaning.`;

const schema = {
  type: "object", additionalProperties: false,
  properties: {
    translations: {
      type: "array",
      items: {
        type: "object", additionalProperties: false,
        properties: { id: { type: "string" }, thai: { type: "string" } },
        required: ["id", "thai"]
      }
    }
  },
  required: ["translations"]
};

if (!fs.existsSync(outputPath)) {
  fs.writeFileSync(outputPath, `# Generated with ${MODEL}; review before publishing.\r\n`, "utf8");
}
console.log(`${name}: ${selected.length} pending ${categories.join(", ")} strings; ${done.size} already present.`);

for (let start = 0; start < selected.length && start / chunkSize < maxBatches; start += chunkSize) {
  const batch = selected.slice(start, start + chunkSize);
  const input = batch.map(row => ({
    id: row.id, category: row.category, english: row.english,
    REQUIRED_VERBATIM_TERMS: requiredTerms(row), speaker: row.speaker, context: row.context
  }));
  // An enum makes an ID substitution impossible even with a small, low-cost model.
  const batchSchema = structuredClone(schema);
  batchSchema.properties.translations.items.properties.id = {
    type: "string", enum: batch.map(row => row.id)
  };
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: MODEL,
      store: false,
      reasoning: { effort: "low" },
      max_output_tokens: 12000,
      instructions,
      input: JSON.stringify(input),
      text: { format: { type: "json_schema", name: "thai_translations", strict: true, schema: batchSchema } }
    })
  });
  const body = await response.json();
  if (!response.ok || body.status !== "completed") {
    throw new Error(`API request failed for batch ${start / chunkSize + 1}: ${body.error?.message ?? body.status ?? JSON.stringify(body)}`);
  }
  let parsed;
  try { parsed = JSON.parse(getOutputText(body)); }
  catch (error) { throw new Error(`API returned invalid JSON: ${error.message}`); }
  const expected = new Map(batch.map(row => [row.id, row]));
  if (!Array.isArray(parsed.translations) || parsed.translations.length !== batch.length) {
    throw new Error(`batch ${start / chunkSize + 1}: expected ${batch.length} translations`);
  }
  const lines = [];
  for (const translation of parsed.translations) {
    const row = expected.get(translation.id);
    if (!row) throw new Error(`batch ${start / chunkSize + 1}: unexpected or duplicate id ${translation.id}`);
    expected.delete(translation.id);
    const thai = translation.thai.replace(/\r?\n/g, "\\n");
    validate(row, thai);
    lines.push(`${translation.id}|${thai}`);
  }
  if (expected.size) throw new Error(`batch ${start / chunkSize + 1}: missing ${[...expected.keys()].join(", ")}`);
  fs.appendFileSync(outputPath, `${lines.join("\r\n")}\r\n`, "utf8");
  console.log(`Completed ${Math.min(start + chunkSize, selected.length)}/${selected.length}; response ${body.id}.`);
}
