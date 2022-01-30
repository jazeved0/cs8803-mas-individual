import * as functions from "firebase-functions";
import * as fetch from "node-fetch";
import admin from "./firebase";
import * as cors from "cors";
import { apiError } from "./api";

// This is a read-only API key
// on a free account; so there's no risk of embedding it here.
const API_KEY = "db0ab04a0e5898f7489adfa40bc08c29";

type TemperatureUnit = "fahrenheit" | "celsius" | "kelvin";

const ALLOWED_TEMP_UNITS = new Set<TemperatureUnit>([
  "fahrenheit",
  "celsius",
  "kelvin",
]);

const UPSTREAM_API_URL = "https://api.openweathermap.org/data/2.5/weather";

const requestsCollection = admin
  .firestore()
  .collection(
    "requests"
  ) as FirebaseFirestore.CollectionReference<RequestLogEntry>;

type RequestLogEntry = {
  latitude: number;
  longitude: number;
  // eslint-disable-next-line camelcase
  temp_unit: TemperatureUnit;
  timestamp: string;
};

type ResponseData = {
  city: string;
  temp: number;
  // eslint-disable-next-line camelcase
  min_temp: number;
  // eslint-disable-next-line camelcase
  max_temp: number;
  weather: string;
  // eslint-disable-next-line camelcase
  weather_icon_url: string;
};

function roundNumber(n: number, digits: number) {
  const pow = Math.pow(10, digits);
  return Math.round(n * pow) / pow;
}

function convertTemperature(kelvin: number, tempUnit: TemperatureUnit): number {
  if (tempUnit == "kelvin") {
    // Try to clean up the floats before returning
    return roundNumber(kelvin, 3);
  } else if (tempUnit == "celsius") {
    // Try to clean up the floats before returning
    return roundNumber(kelvin - 273.15, 3);
  } else {
    // Try to clean up the floats before returning
    return roundNumber((kelvin - 273.15) * (9 / 5) + 32, 3);
  }
}

// Allow all incoming domains for CORS
const corsHandler = cors({ origin: true });

export const getWeather = functions.https.onRequest((request, response) =>
  corsHandler(request, response, async () => {
    const latitudeRaw = request.query["latitude"];
    const longitudeRaw = request.query["longitude"];
    const tempUnitRaw = request.query["temp_unit"];
    if (
      latitudeRaw == null ||
      latitudeRaw.length === 0 ||
      typeof latitudeRaw !== "string"
    ) {
      response
        .status(400)
        .json(
          apiError("request should contain a single 'latitude' query parameter")
        );
      return;
    } else if (
      longitudeRaw == null ||
      longitudeRaw.length === 0 ||
      typeof longitudeRaw !== "string"
    ) {
      response
        .status(400)
        .json(
          apiError(
            "request should contain a single 'longitude' query parameter"
          )
        );
      return;
    } else if (
      tempUnitRaw == null ||
      tempUnitRaw.length === 0 ||
      typeof tempUnitRaw !== "string"
    ) {
      response
        .status(400)
        .json(
          apiError(
            "request should contain a single 'temp_unit' query parameter"
          )
        );
      return;
    } else if (!ALLOWED_TEMP_UNITS.has(tempUnitRaw as TemperatureUnit)) {
      response
        .status(400)
        .json(
          apiError(
            "'temp_unit' query parameter must be one of: ['fahrenheit', 'celsius', 'kelvin']"
          )
        );
      return;
    }

    const latitude = Number.parseFloat(latitudeRaw);
    const longitude = Number.parseFloat(longitudeRaw);
    const tempUnit = tempUnitRaw as TemperatureUnit;

    if (isNaN(longitude)) {
      response
        .status(400)
        .json(apiError("'longitude' query parameter must be a decimal number"));
      return;
    } else if (isNaN(latitude)) {
      response
        .status(400)
        .json(apiError("'latitude' query parameter must be a decimal number"));
      return;
    }

    const timestamp = new Date().toISOString();

    // Fetch the upstream data
    const url = `${UPSTREAM_API_URL}?lat=${latitude}&lon=${longitude}&appid=${API_KEY}`;
    let upstreamResponse: fetch.Response;
    let upstreamResponseBody: string;
    try {
      upstreamResponse = await fetch.default(url, {
        method: "GET",
      });
      upstreamResponseBody = await upstreamResponse.text();
    } catch (err) {
      // Return a 504 (Gateway Timeout)
      response
        .status(504)
        .json(apiError("could not contact upstream OpenWeatherMap API"));
      return;
    }

    let responseData: ResponseData | null = null;
    try {
      const jsonBody = JSON.parse(upstreamResponseBody);
      responseData = {
        city: jsonBody["name"] ?? "",
        temp: convertTemperature(jsonBody["main"]["temp"] ?? 0, tempUnit),
        min_temp: convertTemperature(
          jsonBody["main"]["temp_min"] ?? 0,
          tempUnit
        ),
        max_temp: convertTemperature(
          jsonBody["main"]["temp_max"] ?? 0,
          tempUnit
        ),
        weather: jsonBody["weather"][0]["main"] ?? "",
        weather_icon_url: `http://openweathermap.org/img/wn/${
          jsonBody["weather"][0]["icon"] ?? ""
        }@4x.png`,
      };
    } catch (err) {
      // Return a 500 (Internal Server Error)
      response
        .status(500)
        .json(
          apiError(
            "an error occurred while processing upstream OpenWeatherMap API response"
          )
        );
      return;
    }

    response
      .status(200)
      .header("Content-Type", "application/json")
      .json(responseData);

    // Log the request
    const logEntry: RequestLogEntry = {
      latitude,
      longitude,
      temp_unit: tempUnit,
      timestamp,
    };

    await requestsCollection.add(logEntry);
  })
);
