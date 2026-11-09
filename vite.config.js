import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import leanExerciseCatalog from "./scripts/vite-lean-catalog.mjs";

// Same-origin API gateway used by local development and production-built
// browser integration tests. These unprefixed variables never enter the bundle.
const target = process.env.FORMA_API_TARGET;
const apiProxy = target
  ? {
      "/api": {
        target,
        changeOrigin: false,
        configure(server) {
          server.on("proxyReq", (proxyRequest, request, response) => {
            // `npm run dev` listens on every interface; only this machine may
            // use the proxy that attaches the local Worker secret.
            const peer = request.socket.remoteAddress || "";
            if (!/^(127\.|::1$|::ffff:127\.)/.test(peer)) {
              response.writeHead(403, { "Content-Type": "text/plain" });
              response.end(
                "The FORMA dev API proxy only serves this machine (loopback).",
              );
              proxyRequest.destroy();
              return;
            }
            proxyRequest.removeHeader("x-forma-client-ip");
            proxyRequest.setHeader(
              "x-forma-client-ip",
              request.socket.remoteAddress || "127.0.0.1",
            );
            proxyRequest.removeHeader("cf-access-client-id");
            proxyRequest.removeHeader("cf-access-client-secret");
            proxyRequest.removeHeader("x-forma-worker-secret");
            proxyRequest.setHeader(
              "x-forma-worker-secret",
              process.env.FORMA_DEV_WORKER_SECRET || "",
            );
          });
        },
      },
    }
  : undefined;

export default defineConfig({
  plugins: [leanExerciseCatalog(), react()],
  server: {
    proxy: apiProxy,
    // Browser traces contain HTML; watching generated artifacts reloads live tests.
    watch: {
      ignored: ["**/work/**", "**/test-results/**", "**/playwright-report/**"],
    },
  },
  preview: { proxy: apiProxy },
});
