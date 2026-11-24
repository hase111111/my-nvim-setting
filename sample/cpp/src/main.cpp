#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace bf {

constexpr std::size_t kDefaultTapeSize = 30'000;

class ParseError : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

class RuntimeError : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

struct Program {
  std::string instructions;
  std::unordered_map<std::size_t, std::size_t> jump_targets;
};

bool is_instruction(char character) {
  constexpr std::string_view instructions = "><+-.,[]";
  return instructions.find(character) != std::string_view::npos;
}

Program parse(std::string_view source) {
  Program program;
  std::vector<std::size_t> open_brackets;

  for (char character : source) {
    if (!is_instruction(character)) {
      continue;
    }

    const auto position = program.instructions.size();
    program.instructions.push_back(character);

    if (character == '[') {
      open_brackets.push_back(position);
    } else if (character == ']') {
      if (open_brackets.empty()) {
        throw ParseError("unmatched closing bracket at instruction " +
                         std::to_string(position));
      }

      const auto opening = open_brackets.back();
      open_brackets.pop_back();
      program.jump_targets.emplace(opening, position);
      program.jump_targets.emplace(position, opening);
    }
  }

  if (!open_brackets.empty()) {
    throw ParseError("unmatched opening bracket at instruction " +
                     std::to_string(open_brackets.back()));
  }

  return program;
}

class Interpreter {
 public:
  explicit Interpreter(std::size_t tape_size = kDefaultTapeSize,
                       std::size_t step_limit = 0)
      : tape_(tape_size, 0), step_limit_(step_limit) {
    if (tape_size == 0) {
      throw std::invalid_argument("tape size must be greater than zero");
    }
  }

  void run(const Program& program, std::istream& input, std::ostream& output) {
    std::size_t instruction_pointer = 0;
    std::size_t executed_steps = 0;

    while (instruction_pointer < program.instructions.size()) {
      if (step_limit_ != 0 && executed_steps >= step_limit_) {
        throw RuntimeError("step limit exceeded");
      }
      ++executed_steps;

      const char instruction = program.instructions[instruction_pointer];
      switch (instruction) {
        case '>':
          move_right();
          break;
        case '<':
          move_left();
          break;
        case '+':
          ++tape_[data_pointer_];
          break;
        case '-':
          --tape_[data_pointer_];
          break;
        case '.':
          output.put(static_cast<char>(tape_[data_pointer_]));
          break;
        case ',':
          read_byte(input);
          break;
        case '[':
          if (tape_[data_pointer_] == 0) {
            instruction_pointer = jump_target(program, instruction_pointer);
          }
          break;
        case ']':
          if (tape_[data_pointer_] != 0) {
            instruction_pointer = jump_target(program, instruction_pointer);
          }
          break;
        default:
          throw RuntimeError("internal error: invalid instruction");
      }

      ++instruction_pointer;
    }
  }

 private:
  void move_right() {
    if (data_pointer_ + 1 >= tape_.size()) {
      throw RuntimeError("data pointer moved beyond the right edge of the tape");
    }
    ++data_pointer_;
  }

  void move_left() {
    if (data_pointer_ == 0) {
      throw RuntimeError("data pointer moved beyond the left edge of the tape");
    }
    --data_pointer_;
  }

  void read_byte(std::istream& input) {
    const auto value = input.get();
    tape_[data_pointer_] = value == std::char_traits<char>::eof()
                              ? 0
                              : static_cast<std::uint8_t>(value);
  }

  static std::size_t jump_target(const Program& program, std::size_t position) {
    const auto target = program.jump_targets.find(position);
    if (target == program.jump_targets.end()) {
      throw RuntimeError("internal error: missing jump target");
    }
    return target->second;
  }

  std::vector<std::uint8_t> tape_;
  std::size_t data_pointer_ = 0;
  std::size_t step_limit_ = 0;
};

struct Options {
  std::optional<std::string> source_file;
  std::optional<std::string> inline_code;
  std::size_t tape_size = kDefaultTapeSize;
  std::size_t step_limit = 0;
  bool show_help = false;
};

std::size_t parse_size(std::string_view value, std::string_view option_name) {
  std::size_t consumed = 0;
  unsigned long long parsed = 0;

  try {
    parsed = std::stoull(std::string(value), &consumed);
  } catch (const std::exception&) {
    throw std::invalid_argument("invalid value for " + std::string(option_name));
  }

  if (consumed != value.size() ||
      parsed > std::numeric_limits<std::size_t>::max()) {
    throw std::invalid_argument("invalid value for " + std::string(option_name));
  }

  return static_cast<std::size_t>(parsed);
}

Options parse_arguments(int argc, char* argv[]) {
  Options options;

  for (int index = 1; index < argc; ++index) {
    const std::string_view argument = argv[index];

    auto require_value = [&](std::string_view option) -> std::string_view {
      if (index + 1 >= argc) {
        throw std::invalid_argument("missing value for " + std::string(option));
      }
      return argv[++index];
    };

    if (argument == "-h" || argument == "--help") {
      options.show_help = true;
    } else if (argument == "-e" || argument == "--code") {
      options.inline_code = std::string(require_value(argument));
    } else if (argument == "--tape-size") {
      options.tape_size = parse_size(require_value(argument), argument);
    } else if (argument == "--step-limit") {
      options.step_limit = parse_size(require_value(argument), argument);
    } else if (argument.starts_with('-')) {
      throw std::invalid_argument("unknown option: " + std::string(argument));
    } else if (options.source_file.has_value()) {
      throw std::invalid_argument("only one source file may be specified");
    } else {
      options.source_file = std::string(argument);
    }
  }

  if (options.inline_code.has_value() && options.source_file.has_value()) {
    throw std::invalid_argument("use either --code or a source file, not both");
  }

  return options;
}

std::string read_file(const std::string& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) {
    throw std::runtime_error("could not open source file: " + path);
  }

  std::ostringstream buffer;
  buffer << file.rdbuf();
  if (!file.good() && !file.eof()) {
    throw std::runtime_error("could not read source file: " + path);
  }
  return buffer.str();
}

void print_help(std::ostream& output, std::string_view executable) {
  output << "Brainfuck interpreter written in C++20\n\n"
         << "Usage:\n"
         << "  " << executable << " [options] <source-file>\n"
         << "  " << executable << " [options] --code <program>\n\n"
         << "Options:\n"
         << "  -e, --code <program>  Execute inline source code\n"
         << "      --tape-size <n>   Set the number of tape cells (default: "
         << kDefaultTapeSize << ")\n"
         << "      --step-limit <n>  Stop after n instructions; 0 means unlimited\n"
         << "  -h, --help            Show this help\n";
}

}  // namespace bf

int main(int argc, char* argv[]) {
  try {
    const auto options = bf::parse_arguments(argc, argv);
    if (options.show_help) {
      bf::print_help(std::cout, argc > 0 ? argv[0] : "brainfuck");
      return 0;
    }

    std::string source;
    if (options.inline_code.has_value()) {
      source = *options.inline_code;
    } else if (options.source_file.has_value()) {
      source = bf::read_file(*options.source_file);
    } else {
      throw std::invalid_argument("no source file or inline code was provided");
    }

    const auto program = bf::parse(source);
    bf::Interpreter interpreter(options.tape_size, options.step_limit);
    interpreter.run(program, std::cin, std::cout);
    return 0;
  } catch (const std::exception& error) {
    std::cerr << "error: " << error.what() << '\n';
    return 1;
  }
}

