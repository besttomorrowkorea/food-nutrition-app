const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp();

// Claude API 설정
const anthropicApiKey = defineSecret("ANTHROPIC_API_KEY");
const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";
const CLAUDE_MODEL = "claude-sonnet-4-6";
const ANTHROPIC_VERSION = "2023-06-01";

// 일일 무료 분석 한도 (사용자당)
const FREE_DAILY_LIMIT = 50;

// ─────────────────────────────────────────────────────────────────
// 유틸리티: 일일 사용량 체크 + 증가 (Firestore 트랜잭션)
// ─────────────────────────────────────────────────────────────────
async function checkAndIncrementUsage(uid) {
  const db = getFirestore();
  const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
  const ref = db.doc(`users/${uid}/usage/${today}`);

  return db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const current = doc.exists ? (doc.data().count || 0) : 0;

    if (current >= FREE_DAILY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        `일일 분석 한도(${FREE_DAILY_LIMIT}회)에 도달했습니다. 내일 다시 시도해주세요.`
      );
    }

    tx.set(ref, { count: FieldValue.increment(1), updatedAt: new Date() }, { merge: true });
    return current + 1;
  });
}

// ─────────────────────────────────────────────────────────────────
// 유틸리티: Claude API 호출
// ─────────────────────────────────────────────────────────────────
async function callClaude(apiKey, payload) {
  const response = await fetch(CLAUDE_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorBody = await response.json().catch(() => ({}));
    console.error("Claude API Error:", response.status, JSON.stringify(errorBody));

    if (response.status === 429) {
      const retryAfter = response.headers.get("retry-after") || "30";
      throw new HttpsError(
        "resource-exhausted",
        "AI 서비스가 일시적으로 바쁩니다. 잠시 후 재시도해주세요.",
        { retryAfter }
      );
    }
    if (response.status === 400) {
      throw new HttpsError("invalid-argument", "잘못된 요청입니다.", errorBody);
    }
    throw new HttpsError(
      "internal",
      `AI 서비스 오류가 발생했습니다. (HTTP ${response.status})`
    );
  }

  return response.json();
}

// ─────────────────────────────────────────────────────────────────
// 유틸리티: JSON 추출 (브라켓 스캔 — Claude 응답 변형에 강건)
// ─────────────────────────────────────────────────────────────────
function extractJson(text) {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) {
    console.error("JSON 추출 실패. Raw (200자):", text.slice(0, 200));
    throw new HttpsError("internal", "AI 응답을 파싱할 수 없습니다. 다시 시도해주세요.");
  }
  try {
    return JSON.parse(match[0]);
  } catch (e) {
    console.error("JSON 파싱 실패:", e.message, "| Raw:", text.slice(0, 200));
    throw new HttpsError("internal", "AI 응답 형식 오류입니다. 다시 시도해주세요.");
  }
}

// ─────────────────────────────────────────────────────────────────
// analyzeFood: 음식 사진 → 영양 분석 (Claude Vision)
// ─────────────────────────────────────────────────────────────────
exports.analyzeFood = onCall(
  {
    secrets: [anthropicApiKey],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    // 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const { imageBase64 } = request.data;

    if (!imageBase64 || typeof imageBase64 !== "string") {
      throw new HttpsError("invalid-argument", "이미지 데이터가 필요합니다.");
    }

    // 이미지 크기 제한 (약 4MB base64 기준)
    if (imageBase64.length > 5_500_000) {
      throw new HttpsError(
        "invalid-argument",
        "이미지 크기가 너무 큽니다. 4MB 이하의 이미지를 사용해주세요."
      );
    }

    // base64 유효성 간단 검증
    if (!/^[A-Za-z0-9+/]+=*$/.test(imageBase64.slice(0, 100))) {
      throw new HttpsError("invalid-argument", "올바른 이미지 형식이 아닙니다.");
    }

    // 일일 사용량 체크
    await checkAndIncrementUsage(request.auth.uid);

    try {
      const data = await callClaude(anthropicApiKey.value(), {
        model: CLAUDE_MODEL,
        max_tokens: 1024,
        temperature: 0.3,
        system: `당신은 전문 영양사입니다. 음식 사진을 보고 영양소를 분석해주세요.
반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트는 포함하지 마세요.

{
  "food_name": "음식 이름 (한국어)",
  "food_name_en": "Food name (English)",
  "serving_size": "1인분 기준 예상 중량 (g)",
  "calories": 숫자(kcal),
  "nutrients": {
    "carbohydrates": 숫자(g),
    "protein": 숫자(g),
    "fat": 숫자(g),
    "saturated_fat": 숫자(g),
    "fiber": 숫자(g),
    "sugar": 숫자(g),
    "sodium": 숫자(mg),
    "cholesterol": 숫자(mg)
  },
  "confidence": "high/medium/low",
  "description": "음식에 대한 간단한 설명과 영양 특징 (한국어, 2-3문장)"
}

음식이 아닌 사진이면:
{
  "error": true,
  "message": "음식 사진을 인식할 수 없습니다."
}`,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: "이 음식 사진의 영양소를 분석해주세요.",
              },
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: imageBase64,
                },
              },
            ],
          },
        ],
      });

      const content = data.content[0].text.trim();
      const result = extractJson(content);

      return { success: true, data: result };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("analyzeFood 오류:", error);
      throw new HttpsError("internal", "영양소 분석에 실패했습니다.");
    }
  }
);

// ─────────────────────────────────────────────────────────────────
// chatWithAI: 운동/영양 코칭 챗 (Claude Chat + 날짜 컨텍스트)
// ─────────────────────────────────────────────────────────────────
exports.chatWithAI = onCall(
  {
    secrets: [anthropicApiKey],
    timeoutSeconds: 120,
    memory: "256MiB",
  },
  async (request) => {
    // 인증 확인
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const { message, context } = request.data;
    // context: { userProfile?, recentNutrition?, inBodyRecord?, goal?, chatHistory? }

    if (!message || typeof message !== "string" || message.trim().length === 0) {
      throw new HttpsError("invalid-argument", "메시지를 입력해주세요.");
    }
    if (message.length > 2000) {
      throw new HttpsError("invalid-argument", "메시지가 너무 깁니다. (최대 2000자)");
    }

    // 날짜/시간 컨텍스트 주입 (AI 날짜 감각 해결)
    const now = new Date();
    const dateStr = `${now.getFullYear()}년 ${now.getMonth() + 1}월 ${now.getDate()}일`;
    const weekdays = ["일", "월", "화", "수", "목", "금", "토"];
    const timeStr = `${now.getHours()}시 ${now.getMinutes()}분`;

    let systemPrompt = `당신은 전문 건강 코치이자 영양사입니다. 사용자의 운동과 영양 관리를 도와주세요.

오늘 날짜: ${dateStr} (${weekdays[now.getDay()]}요일)
현재 시각: ${timeStr}`;

    if (context?.userProfile) {
      const p = context.userProfile;
      systemPrompt += "\n\n사용자 정보:";
      if (p.age) systemPrompt += `\n- 나이: ${p.age}세`;
      if (p.height) systemPrompt += `\n- 키: ${p.height}cm`;
      if (p.weight) systemPrompt += `\n- 체중: ${p.weight}kg`;
      if (p.goal) systemPrompt += `\n- 목표: ${p.goal}`;
    }

    if (context?.inBodyRecord) {
      const ib = context.inBodyRecord;
      systemPrompt += `\n\n최신 인바디 기록 (${ib.date}):`;
      if (ib.bodyFatPercentage != null) systemPrompt += `\n- 체지방률: ${ib.bodyFatPercentage}%`;
      if (ib.skeletalMuscleMass != null) systemPrompt += `\n- 골격근량: ${ib.skeletalMuscleMass}kg`;
      if (ib.bmi != null) systemPrompt += `\n- BMI: ${ib.bmi}`;
      if (ib.basalMetabolicRate != null) systemPrompt += `\n- 기초대사량: ${ib.basalMetabolicRate}kcal`;
    }

    if (context?.recentNutrition?.length > 0) {
      systemPrompt += "\n\n최근 영양 기록 (최대 7일):";
      for (const r of context.recentNutrition.slice(0, 7)) {
        systemPrompt += `\n- ${r.date}: ${r.calories}kcal (단백질 ${r.protein}g, 탄수화물 ${r.carbs}g, 지방 ${r.fat}g)`;
      }
    }

    if (context?.goal) {
      const g = context.goal;
      systemPrompt += `\n\n건강 목표: ${g.type}`;
      if (g.targetWeight) systemPrompt += ` / 목표 체중: ${g.targetWeight}kg`;
      if (g.targetDate) systemPrompt += ` / 목표일: ${g.targetDate}`;
    }

    systemPrompt += `\n\n운동 루틴 요청 시 구체적인 세트수, 반복수, 휴식 시간을 포함해주세요.
답변은 한국어로 해주세요. 친근하고 전문적인 톤을 유지하세요.`;

    // 이전 대화 기록 구성 (최대 10개 — 비용 절감)
    const messages = [];
    if (Array.isArray(context?.chatHistory)) {
      for (const h of context.chatHistory.slice(-10)) {
        if (h.role === "user" || h.role === "assistant") {
          messages.push({ role: h.role, content: String(h.content) });
        }
      }
    }
    messages.push({ role: "user", content: message.trim() });

    try {
      const data = await callClaude(anthropicApiKey.value(), {
        model: CLAUDE_MODEL,
        max_tokens: 2048,
        temperature: 0.7,
        system: systemPrompt,
        messages,
      });

      const reply = data.content[0].text.trim();
      return { success: true, reply };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("chatWithAI 오류:", error);
      throw new HttpsError("internal", "AI 응답에 실패했습니다.");
    }
  }
);
