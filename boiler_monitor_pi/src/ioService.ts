import { parseData } from "./stateController";

var Gpio = require("onoff").Gpio; //include onoff to interact with the GPIO

var bit0 = new Gpio(8, "in");
var bit1 = new Gpio(7, "in");
var bit2 = new Gpio(5, "in");
var bit3 = new Gpio(6, "in");
var bit4 = new Gpio(11, "in");
var bit5 = new Gpio(9, "in");
var bit6 = new Gpio(10, "in");
var bit7 = new Gpio(25, "in");

var clk0 = new Gpio(27, "in", "both");
var clk1 = new Gpio(18, "in");

let bytes: string[] = ["", "", "", ""];
let byteIndexes: number[] = [0, 1, 2, 3];
let lastValue: string;
const samples: string[] = ["", "", "", "", "", "", "", "", "", ""];
let sampleIndex = 0;

const lut: Map<string, string> = new Map([
  ["00000001", "8"],
  ["00000101", "9"],
  ["00010001", "6"],
  ["00010011", "E"],
  ["00010101", "5"],
  ["00011011", "F"],
  ["00100001", "0"],
  ["00110011", "C"],
  ["01000011", "2"],
  ["01000101", "3"],
  ["01101101", "7"],
  ["10001101", "4"],
  ["10100001", "U"],
  ["10110011", "L"],
  ["11011011", "r"],
  ["11011111", "-"],
  ["11101101", "1"],
  ["11111111", " "],
]);

let lastClk0 = 0;

function clockChanged() {
  const clockIndex = clk1.readSync() * 2 + lastClk0;
  let bits: string = "";
  bits += bit0.readSync().toString();
  bits += bit1.readSync().toString();
  bits += bit2.readSync().toString();
  bits += bit3.readSync().toString();
  bits += bit4.readSync().toString();
  bits += bit5.readSync().toString();
  bits += bit6.readSync().toString();
  bits += bit7.readSync().toString();

  bytes[clockIndex] = lut.get(bits) ?? " ";
  correctIndex(bytes[clockIndex], clockIndex);

  let output: string =
    bytes[byteIndexes[0]] +
    bytes[byteIndexes[1]] +
    bytes[byteIndexes[2]] +
    bytes[byteIndexes[3]];

  // Filter the output since it occassionally glitches:
  samples[sampleIndex++] = output;
  if (sampleIndex == 10) sampleIndex = 0;
  let sameCount = 0;
  for (let j = 0; j < 10; j++) {
    if (output == samples[j]) sameCount++;
  }

  // Only update if the value changed:
  if (lastValue != output && sameCount > 7) {
    lastValue = output;
    parseData(output);
  }
}

export function initializeIo() {
  clk0.watch((err: any, value: any) => {
    lastClk0 = value;
    clockChanged();
  });
}

function unexportOnClose() {
  //function to run when exiting program
  bit0.unexport();
  bit1.unexport();
  bit2.unexport();
  bit3.unexport();
  bit4.unexport();
  bit5.unexport();
  bit6.unexport();
  bit7.unexport();
  clk0.unexport();
  clk1.unexport();
}

// Because the counter chip can enter the digit sequence at any time, it is
// necessary to adjust the index accordingly.  Since some digits only appear
// at a single position, this function will adjust the index according to
// these unique digits.
function correctIndex(character: String, clockIndex: Number) {
  if (character == "C" || character == "F") {
    // C and F appear only in first digit
    byteIndexes = setFirst(clockIndex);
  } else if (character == "r" || character == "-") {
    // r and - only appear as the last digit
    byteIndexes = setLast(clockIndex);
  } else if (character == "E") {
    byteIndexes = setFirst(clockIndex);
  }
}

function setFirst(num: Number) {
  switch (num) {
    case 0:
      return [0, 1, 2, 3];
    case 1:
      return [1, 2, 3, 0];
    case 2:
      return [2, 3, 0, 1];
    default:
      return [3, 0, 1, 2];
  }
}

function setLast(num: Number) {
  switch (num) {
    case 0:
      return [1, 2, 3, 0];
    case 1:
      return [2, 3, 0, 1];
    case 2:
      return [3, 0, 1, 2];
    default:
      return [0, 1, 2, 3];
  }
}

process.on("SIGINT", unexportOnClose); //function to run when user closes using ctrl+c
