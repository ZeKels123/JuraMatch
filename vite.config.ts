import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// base relative : le site fonctionne sur GitHub Pages quel que soit le nom du dépôt
export default defineConfig({
  base: './',
  plugins: [react()],
})
