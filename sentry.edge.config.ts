import * as Sentry from "@sentry/nextjs";

Sentry.init({
  dsn: "https://8ad220a63ecb0ed42fc44cb2ae54f04a@o4511707775762432.ingest.us.sentry.io/4511707781332992",

  dataCollection: {
    userInfo: false,
  },

  tracesSampleRate: process.env.NODE_ENV === "development" ? 1.0 : 0.1,

  enableLogs: true,
});
