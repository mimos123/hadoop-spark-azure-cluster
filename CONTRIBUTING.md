# 🤝 Contributing to Hadoop & Spark Azure Cluster

First off, thank you for considering contributing to this project! ✨

We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## 🐛 Reporting Issues

We use GitHub issues to track bugs and feature requests. Report a bug by [opening a new issue](https://github.com/mimos123/hadoop-spark-azure-cluster/issues/new).

**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample commands if possible
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or things you tried that didn't work)

### 🔍 Before Reporting an Issue

1. Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Search existing issues to avoid duplicates
3. Verify you're using the correct Hadoop/Spark versions
4. Check if the issue persists after following the [Shutdown/Restart procedures](docs/SHUTDOWN-RESTART.md)

## 💡 Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- A clear and descriptive title
- A detailed description of the proposed functionality
- Explain why this enhancement would be useful
- List any alternative solutions you've considered

## 🔧 Pull Requests

We actively welcome your pull requests!

### Process

1. Fork the repo and create your branch from `main`
2. Make your changes following our style guidelines
3. Test your changes thoroughly
4. Update documentation if needed
5. Ensure your code follows the existing style
6. Submit a pull request!

### Style Guidelines

#### Documentation
- Use clear, concise language
- Include code examples where relevant
- Use emojis sparingly but consistently (🚀 ✅ ⚠️ 🔧)
- Test all commands before including them
- Use proper markdown formatting:
  - Code blocks with syntax highlighting
  - Tables for structured data
  - Numbered lists for procedures
  - Bullet points for lists

#### Scripts
- Include comprehensive comments
- Add descriptive function headers
- Use meaningful variable names
- Include error handling
- Add progress messages
- Make scripts idempotent where possible

#### Configuration Files
- Include inline comments explaining each setting
- Provide reasonable default values
- Note any environment-specific values that need changing

## 🧪 Testing Requirements

Before submitting a pull request:

### For Documentation Changes
- [ ] Verify all commands work as documented
- [ ] Check all links are valid
- [ ] Ensure markdown renders correctly
- [ ] Test procedures from a fresh perspective

### For Script Changes
- [ ] Test on a fresh Azure VM setup
- [ ] Verify error handling works correctly
- [ ] Check scripts are idempotent
- [ ] Ensure proper exit codes
- [ ] Test with both 4GB and 8GB VM configurations

### For Configuration Changes
- [ ] Validate XML syntax
- [ ] Test with Hadoop/Spark startup
- [ ] Verify services start successfully
- [ ] Check web UIs are accessible

## 📋 Code Review Process

1. Maintainers review all pull requests
2. At least one approval required
3. All CI checks must pass
4. Documentation must be updated for any functional changes

## 🎯 What We're Looking For

Contributions that:
- Improve clarity of documentation
- Add troubleshooting for common issues
- Enhance automation scripts
- Optimize configurations
- Fix bugs or typos
- Add useful examples

## ⚖️ Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism gracefully
- Focus on what's best for the community

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Publishing others' private information
- Other unprofessional conduct

## 📞 Getting Help

- Read the [documentation](README.md)
- Check [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- Open an issue with your question
- Be patient and respectful

## 📜 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be recognized in our README and release notes. Thank you for making this project better!

---

**Remember:** Every contribution matters, no matter how small. Whether it's fixing a typo or adding a major feature, we appreciate your effort! 💪
