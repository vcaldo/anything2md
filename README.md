# anything2md

Convert any document or image to Markdown using AI-powered processing. A bash CLI wrapper around the [marker](https://github.com/VikParuchuri/marker) Docker image for seamless document conversion with optional GPU acceleration and LLM enhancement.

## Features

- **Universal Document Conversion**: Convert PDFs, Word documents, Excel spreadsheets, PowerPoint presentations, EPUBs, HTML, and images to Markdown
- **Multiple Output Formats**: Markdown, JSON, HTML, or chunks
- **GPU Acceleration**: Automatic NVIDIA GPU detection and passthrough for faster processing
- **LLM Enhancement**: Optional integration with Gemini, Claude, OpenAI, or Ollama for improved conversion quality
- **Batch Processing**: Convert entire directories with parallel processing support
- **Smart Filtering**: Skip hidden files, already-processed files, and customize with page ranges
- **Docker-Based**: No complex dependencies - just Docker and optionally GPU support
- **Comprehensive CLI**: Built with bashly for robust argument parsing, help text, and shell completions

## Supported File Types

**Documents**: PDF, DOCX, XLSX, PPTX, EPUB, HTML
**Images**: PNG, JPG, JPEG, TIFF, BMP

## Prerequisites

### Required

- **Docker**: Version 20.10 or higher
  - Install from [docker.com](https://docs.docker.com/get-docker/)
  - Verify with `docker --version`

### Optional (for GPU acceleration)

- **NVIDIA GPU**: GeForce, Quadro, Tesla, or similar
- **NVIDIA Driver**: Version 450.80.02 or higher
- **NVIDIA Container Toolkit**: For Docker GPU support
  - Install from [nvidia.com](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
  - Verify with `nvidia-smi` and `docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi`

### For Development

- **Ruby**: Version 2.7 or higher (for bashly)
- **bashly**: Version 1.3.0 or higher
  - Install with `gem install bashly`

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/anything2md.git
cd anything2md
```

### 2. Install Bashly (if not already installed)

```bash
gem install bashly
```

### 3. Generate the CLI

```bash
cd src
bashly generate
cd ..
```

This creates the `./anything2md` executable in the project root.

### 4. Pull the Docker Image

```bash
./anything2md config pull
```

Or manually:

```bash
docker pull xiaoyao9184/marker:latest
```

### 5. Verify Installation

```bash
./anything2md config check
```

This command verifies all dependencies and displays system status.

## Quick Start

### Convert a Single File

```bash
# Basic conversion (outputs to same directory as input)
./anything2md convert document.pdf

# Convert to JSON format
./anything2md convert document.pdf --format json

# Specify output directory
./anything2md convert document.pdf --output-dir ./output
```

### Batch Convert a Directory

```bash
# Convert all supported files in a directory
./anything2md batch ./documents

# Recursive conversion with 4 parallel workers
./anything2md batch ./documents --recursive --workers 4

# Skip already-processed files
./anything2md batch ./documents --skip-processed
```

### Using LLM Enhancement

```bash
# Set API key (Gemini example)
export ANYTHING2MD_GEMINI_API_KEY="your-api-key-here"

# Convert with LLM enhancement
./anything2md convert document.pdf --use-llm --llm-service gemini
```

## Command Reference

### convert (alias: c)

Convert a single file to the specified format.

```bash
./anything2md convert INPUT_FILE [OPTIONS]
```

**Common Options:**
- `--format, -f FORMAT`: Output format (markdown, json, html, chunks) [default: markdown]
- `--output-dir, -o DIR`: Output directory [default: input file directory]
- `--pages, -p RANGE`: Page range (e.g., "0-5,10,15-20")
- `--use-llm, -l`: Enable LLM enhancement
- `--llm-service SERVICE`: LLM service (gemini, claude, openai, ollama) [default: gemini]
- `--force-ocr`: Force OCR for all pages
- `--no-images`: Exclude images from output
- `--debug, -d`: Enable debug output

**Examples:**

```bash
# Basic conversion
./anything2md convert document.pdf

# Convert with custom output directory
./anything2md convert slides.pptx --output-dir ./converted

# Convert specific pages only
./anything2md convert book.pdf --pages "0-10,50-60"

# Force OCR and use LLM enhancement
./anything2md convert scanned.pdf --force-ocr --use-llm
```

For full options, run: `./anything2md convert --help`

### batch (alias: b)

Convert all supported files in a directory.

```bash
./anything2md batch INPUT_DIR [OPTIONS]
```

**Common Options:**
- `--recursive, -r`: Process subdirectories recursively
- `--workers, -w N`: Number of parallel workers [default: 1]
- `--skip-processed`: Skip files that already have output [default: true]
- `--include-hidden`: Include hidden files (starting with .)
- All `convert` command options are also available

**Examples:**

```bash
# Basic batch conversion
./anything2md batch ./documents

# Recursive with 4 parallel workers
./anything2md batch ./documents --recursive --workers 4

# Convert all files, including hidden ones
./anything2md batch ./documents --include-hidden

# Batch with custom output format
./anything2md batch ./pdfs --format json --output-dir ./json-output
```

For full options, run: `./anything2md batch --help`

### config

Manage configuration and verify system status.

#### config check

Verify all dependencies and show system status.

```bash
./anything2md config check
```

#### config pull

Pull or update the marker Docker image.

```bash
./anything2md config pull [--tag TAG]
```

**Example:**
```bash
# Pull latest version
./anything2md config pull

# Pull specific version
./anything2md config pull --tag v1.0.0
```

#### config status

Show comprehensive system status and configuration.

```bash
./anything2md config status
```

#### config gpu

Display detailed GPU information.

```bash
./anything2md config gpu
```

#### config env

List all environment variables.

```bash
./anything2md config env [--export] [--show-secrets]
```

**Examples:**
```bash
# Show all environment variables
./anything2md config env

# Export format for sourcing
./anything2md config env --export > .env

# Show API keys (normally masked)
./anything2md config env --show-secrets
```

## Configuration

### Environment Variables

All environment variables use the `ANYTHING2MD_` prefix and can be set in your shell or via a `.env` file.

| Variable | Description | Default |
|----------|-------------|---------|
| `ANYTHING2MD_OUTPUT_FORMAT` | Default output format | `markdown` |
| `ANYTHING2MD_OUTPUT_DIR` | Default output directory | (input file directory) |
| `ANYTHING2MD_VRAM` | GPU VRAM limit in GB | (auto-detect) |
| `ANYTHING2MD_LLM_SERVICE` | Default LLM service | `gemini` |
| `ANYTHING2MD_GEMINI_API_KEY` | Google Gemini API key | (none) |
| `ANYTHING2MD_ANTHROPIC_API_KEY` | Anthropic Claude API key | (none) |
| `ANYTHING2MD_OPENAI_API_KEY` | OpenAI API key | (none) |
| `ANYTHING2MD_OLLAMA_URL` | Ollama server URL | `http://localhost:11434` |
| `ANYTHING2MD_DEBUG` | Enable debug logging | `0` |

### LLM Setup

To use LLM enhancement, set the appropriate API key for your chosen service:

#### Google Gemini (default)

1. Get an API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Set the environment variable:
   ```bash
   export ANYTHING2MD_GEMINI_API_KEY="your-api-key-here"
   ```
3. Use with: `./anything2md convert file.pdf --use-llm`

#### Anthropic Claude

1. Get an API key from [Anthropic Console](https://console.anthropic.com/)
2. Set the environment variable:
   ```bash
   export ANYTHING2MD_ANTHROPIC_API_KEY="your-api-key-here"
   ```
3. Use with: `./anything2md convert file.pdf --use-llm --llm-service claude`

#### OpenAI

1. Get an API key from [OpenAI Platform](https://platform.openai.com/api-keys)
2. Set the environment variable:
   ```bash
   export ANYTHING2MD_OPENAI_API_KEY="your-api-key-here"
   ```
3. Use with: `./anything2md convert file.pdf --use-llm --llm-service openai`

#### Ollama (local)

1. Install and run [Ollama](https://ollama.ai/)
2. Ensure Ollama is running on `http://localhost:11434` (or set custom URL)
3. Use with: `./anything2md convert file.pdf --use-llm --llm-service ollama`

## Exit Codes

The CLI uses specific exit codes to indicate different error conditions:

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | Operation completed successfully |
| 1 | Invalid arguments | Missing required arguments or invalid options |
| 2 | File not found | Input file does not exist or is not readable |
| 3 | Unsupported type | File extension not supported |
| 4 | Container error | Docker error or marker image not available |
| 5 | Conversion failed | Conversion process failed |
| 6 | Directory not found | Input directory does not exist |
| 7 | Partial failure | Some files in batch conversion failed |

## Troubleshooting

### Docker Issues

**Problem**: "Docker daemon is not running"

**Solution**:
```bash
# Start Docker Desktop (macOS/Windows)
# Or start Docker service (Linux)
sudo systemctl start docker

# Verify Docker is running
docker ps
```

**Problem**: "marker image not found"

**Solution**:
```bash
./anything2md config pull
```

### GPU Issues

**Problem**: "NVIDIA GPU not detected"

**Solution**:
1. Verify GPU driver is installed: `nvidia-smi`
2. Install NVIDIA Container Toolkit: [Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
3. Verify Docker GPU access: `docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi`

**Problem**: GPU detected but not being used

**Solution**:
1. Check GPU status: `./anything2md config gpu`
2. Enable debug mode to verify GPU passthrough: `./anything2md convert file.pdf --debug`
3. Look for `--gpus all` in the Docker command output

### Conversion Issues

**Problem**: Conversion fails with "unsupported file type"

**Solution**:
- Verify file extension is supported (use `./anything2md --help` to see list)
- Check file is not corrupted: try opening it in its native application
- Try forcing OCR if it's an image-based PDF: `--force-ocr`

**Problem**: Out of memory during conversion

**Solution**:
- Limit VRAM usage: `--vram 4` (adjust number based on available memory)
- Process fewer pages at a time: `--pages "0-50"`
- Reduce parallel workers in batch mode: `--workers 2`

**Problem**: LLM enhancement fails

**Solution**:
1. Verify API key is set correctly: `./anything2md config env`
2. Check API key is valid and has quota available
3. Try with debug mode: `--debug` to see detailed error messages
4. For Ollama, verify server is running: `curl http://localhost:11434/api/version`

### Performance Issues

**Problem**: Conversions are slow

**Solution**:
- Enable GPU acceleration (if available): verify with `./anything2md config gpu`
- Use parallel workers for batch processing: `--workers 4`
- Skip already-processed files: `--skip-processed`
- Consider using `--no-images` if images aren't needed

## Shell Completions

Enable tab completion for commands, options, and file arguments.

### Bash

Add to your `~/.bashrc`:

```bash
eval "$(anything2md completions)"
```

### Zsh

Add to your `~/.zshrc`:

```bash
eval "$(anything2md completions)"
```

After adding, reload your shell or run `source ~/.bashrc` (or `~/.zshrc`) to activate completions.

## Development

### Project Structure

```
anything2md/
├── src/
│   ├── bashly.yml              # CLI configuration
│   ├── initialize.sh           # Library initialization
│   ├── before.sh               # Pre-flight checks
│   ├── convert_command.sh      # Convert command implementation
│   ├── batch_command.sh        # Batch command implementation
│   ├── config_*_command.sh     # Config subcommands
│   └── lib/
│       ├── constants.sh        # Exit codes and constants
│       ├── output.sh           # Logging and formatting
│       ├── validation.sh       # Input validation
│       ├── gpu.sh              # GPU detection
│       ├── docker.sh           # Docker command building
│       ├── files.sh            # File operations
│       └── conversion.sh       # Conversion orchestration
├── anything2md                 # Generated CLI executable
└── README.md                   # This file
```

### Regenerating the CLI

After modifying any files in `src/`:

```bash
cd src
bashly generate
cd ..
```

### Running Tests

Test fixtures are in the `conversion_tests/` directory:

```bash
# Test single file conversion
./anything2md convert conversion_tests/pdf/sample.pdf

# Test batch processing
./anything2md batch conversion_tests/pdf/

# Test with debug output
./anything2md convert conversion_tests/pdf/sample.pdf --debug
```

### Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly (especially with `shellcheck`)
5. Submit a pull request

### Code Quality

All shell scripts are checked with shellcheck:

```bash
shellcheck src/**/*.sh
```

## License

[Specify your license here - MIT, Apache 2.0, GPL, etc.]

## Credits

- Built with [bashly](https://bashly.dannyb.co/) - Bash CLI framework
- Uses [marker](https://github.com/VikParuchuri/marker) - Convert PDF to markdown with high accuracy
- Docker image: [xiaoyao9184/marker](https://hub.docker.com/r/xiaoyao9184/marker)

## Support

- Report issues: [GitHub Issues](https://github.com/yourusername/anything2md/issues)
- Documentation: Run `./anything2md --help` or `./anything2md COMMAND --help`
- System status: `./anything2md config check`

---

**Note**: This tool is a wrapper around the marker project. For issues specific to the conversion engine, please refer to the [marker repository](https://github.com/VikParuchuri/marker).
