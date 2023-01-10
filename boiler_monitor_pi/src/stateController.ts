import { FieldValue } from "firebase-admin/firestore";
import { addStateData, addTemperatureData, setState } from "./dbService";
import { log } from "./logService";
import { sendNotifications } from "./messagingService";

let isEngaged: boolean | null = null;
let isWorking: boolean | null = null;
let isFuelError: boolean | null = null;
let isOvertempError: boolean | null = null;
let boilerStoppedAtTime: Date | null = null;
const minutesToStoppedWarning = 5;

export async function parseData(output: string) {
  log(new Date().toLocaleString() + ": " + output);
  if (/E  \d/g.test(output)) {
    log("OVERTEMP");
    sendNotifications(
      "Boiler overtemp!",
      "The boiler monitor had detected an overtemp condition.",
    );
    addTemperatureData(null);
    setOvertempError(true);
  } else if (/FUEL/g.test(output)) {
    log("FUEL");
    sendNotifications(
      "Boiler out of fuel!",
      "The boiler monitor has dectected an out of fuel condition.",
    );
    setFuelError(true);
    addTemperatureData(null);
  } else if (/F\d{3}/g.test(output)) {
    // Working
    setEngaged(true);
    setWorking(true);
    addTemperatureData(parseInt(output.substring(1)));
  } else if (/\d{3}r/g.test(output)) {
    // Idling
    setEngaged(true);
    setWorking(false);
    addTemperatureData(parseInt(output.substring(0, 3)));
  } else if (/\d{3}-/g.test(output)) {
    log("Disengaged");
    setFuelError(false);
    setOvertempError(false);
    setEngaged(false);
    addTemperatureData(parseInt(output.substring(0, 3)));
  }
}

function setWorking(newIsWorking: boolean) {
  if (isWorking == null) isWorking = newIsWorking;
  if (newIsWorking && !isWorking) {
    isWorking = newIsWorking;
    addStateData("WORK");
    setState({ working: newIsWorking });
  } else if (!newIsWorking && isWorking) {
    isWorking = newIsWorking;
    addStateData("IDLE");
    setState({ working: newIsWorking });
  }
}

function setFuelError(newIsFuelError: boolean) {
  if (isFuelError == null) isFuelError = newIsFuelError;
  if (newIsFuelError && !isFuelError) {
    isFuelError = newIsFuelError;
    addStateData("FUEL");
    setState({ fuel: newIsFuelError });
  } else if (!newIsFuelError && isFuelError) {
    isFuelError = newIsFuelError;
    addStateData("FUEL-RESOLVE");
    setState({ fuel: newIsFuelError });
  }
}

function setOvertempError(newIsOvertempError: boolean) {
  if (isOvertempError == null) isOvertempError = newIsOvertempError;
  if (newIsOvertempError && !isOvertempError) {
    isOvertempError = newIsOvertempError;
    addStateData("OVERTEMP");
    setState({ error: newIsOvertempError });
  } else if (!newIsOvertempError && isOvertempError) {
    isOvertempError = newIsOvertempError;
    addStateData("OVERTEMP-RESOLVE");
    setState({ error: newIsOvertempError });
  }
}

function setEngaged(newIsEngaged: boolean) {
  if (isEngaged == null) isEngaged = newIsEngaged;
  if (newIsEngaged && !isEngaged) {
    isEngaged = newIsEngaged;
    addStateData("ENGAGED");
    boilerStoppedAtTime = null;
    log("Boiler started.");
    setState({
      engaged: newIsEngaged,
      lastTendedAt: FieldValue.serverTimestamp(),
    });
  } else if (!newIsEngaged && isEngaged) {
    isEngaged = newIsEngaged;
    addStateData("DISENGAGED");
    monitorForWarning();
    setState({ engaged: newIsEngaged });
  }
}

async function monitorForWarning() {
  if (boilerStoppedAtTime == null && !isEngaged) {
    boilerStoppedAtTime = new Date();
    log("Boiler stopped.");
    setTimeout(function () {
      if (boilerStoppedAtTime != null) {
        const timeAgo = new Date();
        timeAgo.setMinutes(timeAgo.getMinutes() - minutesToStoppedWarning);
        if (boilerStoppedAtTime < timeAgo) {
          sendNotifications(
            "Boiler stopped!",
            "Did you forget to restart the boiler?",
          );
          log("Reminder sent to restart boiler.");
        }
      }
    }, 1000 * 61 * minutesToStoppedWarning);
  }
}
