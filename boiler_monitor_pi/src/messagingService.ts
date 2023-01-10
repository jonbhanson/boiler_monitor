import {
  getMessaging,
  Messaging,
  MulticastMessage
} from "firebase-admin/messaging";
import { getTokens, removePushToken } from "./dbService";
import { log } from "./logService";

let messaging: Messaging;
const tokenMap = new Map<string, string>();
const tokenList: string[] = [];

export async function initializeFCM() {
  messaging = getMessaging();
  const data = await getTokens();
  if (data) {
    for (const key in data) {
      tokenMap.set(data[key], key);
      tokenList.push(data[key]);
    }
  }
}

export function sendNotifications(title: string, body: string) {
  const message: MulticastMessage = {
    tokens: tokenList,
    android: {
      priority: "high",
      notification: { defaultSound: true, defaultVibrateTimings: true },
    },
    notification: { body: body, title: title },
  };

  messaging.sendMulticast(message).then((response) => {
    if (response.failureCount > 0) {
      response.responses.forEach((response, index) => {
        if (!response.success) {
          log(`removing token at index ${index}: ${tokenList[index]}`);
          const keyToDelete = tokenMap.get(tokenList[index]);
          if (keyToDelete) removePushToken(keyToDelete);
        }
      });
    }
  });
}
