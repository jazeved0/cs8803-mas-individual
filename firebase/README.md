# Firebase Configuration

This repository contains the configuration for [Firebase Cloud Firestore](https://firebase.google.com/products/firestore) and the source code for [Firebase Cloud Functions](https://firebase.google.com/products/functions). They are used by the weather app to proxy requests to the upstream OpenWeatherMap API and log incoming requests for usage analysis.

## 🚀 Developing functions

To work with with the Cloud Functions in this repository, run the following commands from within the `/functions` directory (make sure you have Node.js 14+ and Yarn v1 installed beforehand):

```sh
npm install -g firebase-tools
yarn install
yarn build
yarn serve
```

You should then be able to access the [Firebase local emulator suite](https://firebase.google.com/docs/emulator-suite) running at http://localhost:4000/, and run functions at their URLs.
