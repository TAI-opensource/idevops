"use client";

import { record } from "rrweb";
import type { eventWithTime, recordOptions } from "rrweb";

let stopFn: (() => void) | null = null;

const events: eventWithTime[] = [];

const config: recordOptions<eventWithTime> = {
  emit(event) {
    events.push(event);
  },
  maskAllInputs: true,
  maskAllText: true,
  blockClass: "rr-block",
  slimDOMOptions: {
    script: true,
    comment: true,
  },
};

export function startRecording() {
  if (typeof window === "undefined") return;

  stopFn = record(config);
  return stopFn;
}

export function stopRecording() {
  if (stopFn) {
    stopFn();
    stopFn = null;
  }
  return events;
}

export function getEvents() {
  return events;
}

export function clearEvents() {
  events.length = 0;
}

export function addCustomEvent(tag: string, payload: unknown) {
  if (typeof window !== "undefined") {
    record.addCustomEvent(tag, payload);
  }
}

export async function sendEventsToServer(endpoint: string) {
  const recordedEvents = stopRecording();

  if (recordedEvents.length === 0) return;

  try {
    await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        events: recordedEvents,
        timestamp: Date.now(),
        url: window.location.href,
      }),
    });
    clearEvents();
  } catch (error) {
    console.error("Failed to send recording events:", error);
  }
}
