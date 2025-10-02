# Contributing to Sleex

**Thanks for your interest in contributing to Sleex!**
This project exists because of passionate people like you who want to build a clean, modern, and hackable desktop environment. Contributions of all kinds are welcome—code, documentation, bug reports, or even just good ideas.

## 🛠 How to Contribute
### 1. Reporting Issues
- Use the [issue tracker](https://github.com/axos-project/sleex/issues)
- Be clear and descriptive: explain what you expected to happen vs. what actually happened.
- Include logs, screenshots, or configs if relevant.
- Use labels when possible (bug, enhancement, docs, etc.).

### 2. Suggesting Features

- Check if the idea already exists in the issues or discussions.
- Open a new issue with the `enhancement` label.
- Keep it realistic

### 3. Submitting Code

- Fork the repo and create a feature branch:

  ```
  git checkout -b feature/your-feature
  ```
- Test your changes on a real session before submitting.
- Commit messages should be short and meaningful:

  ```
  feat: add brightness plugin
  fix: resolve crash on startup
  ```
- Squash if too many commits have the same purpose

### 4. Pull Requests

- PRs should be focused (one feature/fix per PR).
- Reference the related issue if one exists (Fixes #123).
- Write a summary of what your PR does.
- Expect feedback—reviews are collaborative, not personal.

## 🧪 Testing

- Test locally on Wayland with **Quickshell + Sleex** running.
- Check that no regressions occur in core features (panels, windows, keybindings).
- Automated tests are limited, so manual testing matters a lot.
