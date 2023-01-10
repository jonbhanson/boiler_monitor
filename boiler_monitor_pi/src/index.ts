import { initializeApp } from "firebase-admin/app";
import { initializeDb } from "./dbService";
import { initializeIo } from "./ioService";
import { log } from "./logService";
import { initializeFCM } from "./messagingService";
var admin = require("firebase-admin");
var serviceAccount = require("/home/jon/boiler-monitor/boiler-monitor-c6c14-firebase-adminsdk-onhag-82b24e2ff7.json");

async function initialize() {
  initializeApp({ credential: admin.credential.cert(serviceAccount) });
  initializeDb();
  await initializeFCM();
  initializeIo();
  log("Boiler monitor started!");
}
initialize();
