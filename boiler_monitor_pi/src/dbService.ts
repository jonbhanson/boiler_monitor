import {
  FieldPath,
  FieldValue,
  getFirestore,
  Timestamp
} from "firebase-admin/firestore";

let db: FirebaseFirestore.Firestore;
let lastTemperature: number | null = null;

export function initializeDb() {
  db = getFirestore();
}

export async function getTokens() {
  const doc = await db.doc("settings/tokens").get();
  const data = doc.data();
  return data;
}

export function removePushToken(key: string) {
  const fieldPath: any = new FieldPath(key);
  db.doc("settings/tokens").update(fieldPath, FieldValue.delete());
}

export function setState(newValue: { [k: string]: boolean | FieldValue }) {
  db.doc(`settings/state`).set(newValue, { merge: true });
}

export async function addTemperatureData(output: number | null) {
  // There may be a gap between the last temperature before the null is added,
  // so readd the last temperature with the current timestamp before adding
  // the null value.
  if (output != null) lastTemperature = output;
  if (output == null && lastTemperature != null)
    await addTemperatureData(lastTemperature);
  if (typeof output === "number" && output > 250) return;
  const iso = new Date().toISOString().split("T");
  const date = iso[0];
  const time = iso[1];

  // Obtain a document reference.
  const document = db.doc(`days/${date}`);

  // Enter new data into the document.
  await document.set(
    { [time]: output, date: getTodaysTimestamp() },
    { merge: true },
  );
}

export function addStateData(output: String) {
  const iso = new Date().toISOString().split("T");
  const date = iso[0];
  const time = iso[1];

  // Obtain a document reference.
  const document = db.doc(`state/${date}`);

  // Enter new data into the document.
  document.set({ [time]: output, date: getTodaysTimestamp() }, { merge: true });
}

function getTodaysTimestamp() {
  const date: Date = new Date();
  date.setHours(0, 0, 0, 0);
  return Timestamp.fromDate(date);
}
