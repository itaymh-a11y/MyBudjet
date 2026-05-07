const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function sumByCategory(expenses) {
  const out = {};
  for (const item of expenses || []) {
    const categoryId = String(item.categoryId || "");
    if (!categoryId) continue;
    out[categoryId] = (out[categoryId] || 0) + toNumber(item.amount);
  }
  return out;
}

function computeMockPlan(body) {
  const budget = Math.max(0, toNumber(body.budget));
  const categories = Array.isArray(body.categories) ? body.categories : [];
  const templates = Array.isArray(body.templates) ? body.templates : [];
  const pastCycles = Array.isArray(body.expensesPerPastCycles)
    ? body.expensesPerPastCycles
    : [];
  const currentExpenses = Array.isArray(body.currentExpenses)
    ? body.currentExpenses
    : [];

  const fixedByCategory = {};
  for (const t of templates) {
    const categoryId = String(t.categoryId || "");
    if (!categoryId) continue;
    fixedByCategory[categoryId] =
      (fixedByCategory[categoryId] || 0) + toNumber(t.amount);
  }
  const totalFixedRecurring = Object.values(fixedByCategory).reduce(
    (a, b) => a + b,
    0
  );
  const flexiblePool = Math.max(0, budget - totalFixedRecurring);

  const categoryIds = categories.map((c) => String(c.id || "")).filter(Boolean);
  const sumShare = Object.fromEntries(categoryIds.map((id) => [id, 0]));
  let cyclesUsed = 0;

  for (const cycle of pastCycles) {
    const spentByCategory = sumByCategory(cycle);
    let cycleFlexibleTotal = 0;
    const cycleFlexByCategory = {};
    for (const id of categoryIds) {
      const spent = toNumber(spentByCategory[id]);
      const fixed = toNumber(fixedByCategory[id]);
      const flexible = Math.max(0, spent - fixed);
      cycleFlexByCategory[id] = flexible;
      cycleFlexibleTotal += flexible;
    }
    if (cycleFlexibleTotal <= 0) continue;
    cyclesUsed += 1;
    for (const id of categoryIds) {
      sumShare[id] += cycleFlexByCategory[id] / cycleFlexibleTotal;
    }
  }

  const normalizedShare = {};
  if (cyclesUsed > 0) {
    let rawSum = 0;
    for (const id of categoryIds) {
      normalizedShare[id] = sumShare[id] / cyclesUsed;
      rawSum += normalizedShare[id];
    }
    if (rawSum > 0) {
      for (const id of categoryIds) {
        normalizedShare[id] = normalizedShare[id] / rawSum;
      }
    }
  }
  for (const id of categoryIds) {
    if (!Number.isFinite(normalizedShare[id])) normalizedShare[id] = 0;
  }

  const spentCurrentByCategory = sumByCategory(currentExpenses);
  const rows = categories.map((c) => {
    const id = String(c.id || "");
    const fixed = toNumber(fixedByCategory[id]);
    const portion = toNumber(normalizedShare[id]);
    const idealTotal = fixed + flexiblePool * portion;
    return {
      categoryId: id,
      categoryName: String(c.name || ""),
      fixedFromRecurring: fixed,
      flexiblePortionOfPool: portion,
      idealTotal,
      spentCurrent: toNumber(spentCurrentByCategory[id]),
    };
  });
  rows.sort((a, b) => b.idealTotal - a.idealTotal);

  return {
    budget,
    totalFixedRecurring,
    flexiblePool,
    pastCyclesUsedForAverage: cyclesUsed,
    categories: rows,
  };
}

function buildAiPrompt(body) {
  const budget = Math.max(0, toNumber(body.budget));
  const categories = Array.isArray(body.categories) ? body.categories : [];
  const templates = Array.isArray(body.templates) ? body.templates : [];
  const pastCycles = Array.isArray(body.expensesPerPastCycles)
    ? body.expensesPerPastCycles
    : [];
  const currentExpenses = Array.isArray(body.currentExpenses)
    ? body.currentExpenses
    : [];

  return `
You are a budgeting assistant. Return ONLY valid JSON.
Goal: suggest ideal category allocation for a target budget while keeping recurring expenses as mandatory.

Rules:
1) Keep recurring (templates) as fixed mandatory amounts per category.
2) Distribute remaining budget mostly based on historical behavior from past cycles.
3) Prefer reducing discretionary categories first when target budget is tight.
4) Ensure all category totals are >= 0.
5) Sum of idealTotal across categories should be close to target budget (small rounding differences are OK).
6) Keep response schema exactly as requested.

Return JSON schema:
{
  "budget": number,
  "totalFixedRecurring": number,
  "flexiblePool": number,
  "pastCyclesUsedForAverage": number,
  "categories": [
    {
      "categoryId": string,
      "categoryName": string,
      "fixedFromRecurring": number,
      "flexiblePortionOfPool": number,
      "idealTotal": number,
      "spentCurrent": number
    }
  ]
}

Input data:
${JSON.stringify(
    {
      budget,
      categories,
      templates,
      expensesPerPastCycles: pastCycles,
      currentExpenses,
    },
    null,
    2
  )}
`;
}

function sanitizeAiOutput(output, inputBody) {
  const fallback = computeMockPlan(inputBody);
  if (!output || typeof output !== "object") return fallback;

  const budget = Math.max(0, toNumber(output.budget));
  const totalFixedRecurring = Math.max(0, toNumber(output.totalFixedRecurring));
  const flexiblePool = Math.max(0, toNumber(output.flexiblePool));
  const pastCyclesUsedForAverage = Math.max(
    0,
    Math.trunc(toNumber(output.pastCyclesUsedForAverage))
  );

  const categoriesIn = Array.isArray(output.categories) ? output.categories : [];
  const categories = categoriesIn
    .map((row) => ({
      categoryId: String(row.categoryId || ""),
      categoryName: String(row.categoryName || ""),
      fixedFromRecurring: Math.max(0, toNumber(row.fixedFromRecurring)),
      flexiblePortionOfPool: Math.max(0, toNumber(row.flexiblePortionOfPool)),
      idealTotal: Math.max(0, toNumber(row.idealTotal)),
      spentCurrent: Math.max(0, toNumber(row.spentCurrent)),
    }))
    .filter((row) => row.categoryId);

  if (categories.length === 0) return fallback;
  categories.sort((a, b) => b.idealTotal - a.idealTotal);

  return {
    budget: budget || fallback.budget,
    totalFixedRecurring:
      totalFixedRecurring || fallback.totalFixedRecurring,
    flexiblePool,
    pastCyclesUsedForAverage:
      pastCyclesUsedForAverage || fallback.pastCyclesUsedForAverage,
    categories,
  };
}

async function computeAiPlan(body) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error("OPENAI_API_KEY is missing");
  }

  const model = process.env.OPENAI_MODEL || "gpt-4o-mini";
  const prompt = buildAiPrompt(body);

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: "You are a precise budgeting engine. Return JSON only.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`OpenAI request failed (${response.status}): ${errorBody}`);
  }

  const data = await response.json();
  const content =
    data?.choices?.[0]?.message?.content &&
    String(data.choices[0].message.content);
  if (!content) {
    throw new Error("OpenAI response has no content");
  }

  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (error) {
    throw new Error(`OpenAI returned invalid JSON: ${error.message}`);
  }
  return sanitizeAiOutput(parsed, body);
}

exports.aiIdealBudget = onRequest({ cors: true }, (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method Not Allowed" });
    return;
  }
  const body = req.body || {};
  const useAi = Boolean(body.useAi);

  const sendMock = () => {
    const result = computeMockPlan(body);
    res.status(200).json(result);
  };

  if (!useAi) {
    sendMock();
    return;
  }

  computeAiPlan(body)
    .then((result) => {
      res.status(200).json(result);
    })
    .catch((error) => {
      logger.error("aiIdealBudget AI failed, fallback to mock", error);
      sendMock();
    });
});

exports.aiIdealBudgetHealth = onRequest({ cors: true }, (_req, res) => {
  try {
    res.status(200).json({
      ok: true,
      hasOpenAiKey: Boolean(process.env.OPENAI_API_KEY),
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
    });
  } catch (error) {
    logger.error("aiIdealBudgetHealth failed", error);
    res.status(500).json({ ok: false });
  }
});
