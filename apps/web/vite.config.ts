import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import tailwindcss from "@tailwindcss/vite"
import { fileURLToPath, URL } from "node:url"
export default defineConfig({ plugins: [react(), tailwindcss()], resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } }, server: { proxy: { "/api": process.env.GCF_API_PROXY || "http://gcf-api-dev:4000", "/live": { target: process.env.GCF_API_PROXY || "http://gcf-api-dev:4000", ws: true } } } })
