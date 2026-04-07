const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { default: fetch } = require("node-fetch");

// Firebase Secret Manager로 API 키 관리
const openaiApiKey = defineSecret("OPENAI_API_KEY");

exports.analyzeFood = onCall(
  {
    secrets: [openaiApiKey],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    // 인증 확인 (필요 시)
    // if (!request.auth) {
    //   throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    // }

    const { imageBase64 } = request.data;

    if (!imageBase64) {
      throw new HttpsError("invalid-argument", "이미지 데이터가 필요합니다.");
    }

    // 이미지 크기 제한 (약 4MB base64 기준)
    if (imageBase64.length > 5_500_000) {
      throw new HttpsError(
        "invalid-argument",
        "이미지 크기가 너무 큽니다. 4MB 이하의 이미지를 사용해주세요."
      );
    }

    try {
      const response = await fetch(
        "https://api.openai.com/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${openaiApiKey.value()}`,
          },
          body: JSON.stringify({
            model: "gpt-4o",
            messages: [
              {
                role: "system",
                content: `당신은 전문 영양사입니다. 음식 사진을 보고 영양소를 분석해주세요.
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
              },
              {
                role: "user",
                content: [
                  {
                    type: "text",
                    text: "이 음식 사진의 영양소를 분석해주세요.",
                  },
                  {
                    type: "image_url",
                    image_url: {
                      url: `data:image/jpeg;base64,${imageBase64}`,
                      detail: "high",
                    },
                  },
                ],
              },
            ],
            max_tokens: 800,
            temperature: 0.3,
          }),
        }
      );

      if (!response.ok) {
        const errorBody = await response.text();
        console.error("OpenAI API Error:", response.status, errorBody);
        throw new HttpsError(
          "internal",
          "AI 분석 중 오류가 발생했습니다."
        );
      }

      const data = await response.json();
      const content = data.choices[0].message.content.trim();

      // JSON 파싱 (마크다운 코드블록 제거)
      const jsonStr = content.replace(/```json\n?|```\n?/g, "").trim();
      const result = JSON.parse(jsonStr);

      return { success: true, data: result };
    } catch (error) {
      if (error instanceof HttpsError) throw error;

      console.error("분석 오류:", error);
      throw new HttpsError("internal", "영양소 분석에 실패했습니다.");
    }
  }
);
