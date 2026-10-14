import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Same-origin API gateway used by local development and production-built
// browser integration tests. These unprefixed variables never enter the bundle.
const target = process.env.FORMA_API_TARGET;
const apiProxy = target
  ? {
      "/api": {
        target,
        changeOrigin: false,
        configure(server) {
          server.on("proxyReq", (proxyRequest, request) => {
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
  plugins: [react()],
  server: {
    proxy: apiProxy,
    // Browser traces contain HTML; watching generated artifacts reloads live tests.
    watch: {
      ignored: ["**/work/**", "**/test-results/**", "**/playwright-report/**"],
    },
  },
  preview: { proxy: apiProxy },
});
