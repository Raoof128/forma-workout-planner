// Playwright 1.64.1's macOS WebKit follows the host keyboard-navigation mode.
// NSArgumentDomain makes this a volatile process preference, never an OS write.
export function webkitLaunchOptions({
  headless = !(
    process.argv.includes("--headed") ||
    process.argv.includes("--debug") ||
    process.env.PWDEBUG === "1"
  ),
} = {}) {
  if (process.platform !== "darwin") return {};
  return {
    // The pinned WebKit defaultArgs rejects the separate numeric Cocoa value.
    // Preserve its exact nonpersistent flags here; reverify on Playwright upgrades.
    ignoreDefaultArgs: true,
    args: [
      "--inspector-pipe",
      ...(headless ? ["--headless"] : []),
      "--no-startup-window",
      "-AppleKeyboardUIMode",
      "3",
    ],
  };
}
