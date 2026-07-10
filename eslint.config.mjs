import { defineConfig, globalIgnores } from "eslint/config";
import prettierConfig from "eslint-config-prettier";

const eslintConfig = defineConfig([
  globalIgnores([
    "node_modules/**",
    "actions/**",
    ".next/**",
    "out/**",
    "dist/**",
  ]),
  prettierConfig,
]);

export default eslintConfig;
