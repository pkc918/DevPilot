import { createServer } from "node:net";

const port = Number.parseInt(process.argv[2] || "", 10);
if (!Number.isInteger(port) || port < 1 || port > 65_535) {
  throw new Error("Usage: node --experimental-strip-types tests/fixture-listener.ts <port>");
}

const server = createServer();
server.listen(port, "127.0.0.1", () => {
  process.stdout.write(`fixture-listener-ready:${port}\n`);
});

const close = (): void => {
  server.close(() => process.exit(0));
};

process.on("SIGINT", close);
process.on("SIGTERM", close);
