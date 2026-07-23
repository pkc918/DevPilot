import { defineConfig } from "vitest/config";

export default defineConfig({
  root: "src",
  clearScreen: false,
  server: {
    strictPort: true,
    host: "127.0.0.1",
    port: 1420,
  },
  envPrefix: ["VITE_", "TAURI_ENV_"],
  test: {
    root: ".",
  },
  build: {
    target: "chrome105",
    minify: "esbuild",
    sourcemap: false,
    outDir: "../dist",
    emptyOutDir: true,
  },
});
