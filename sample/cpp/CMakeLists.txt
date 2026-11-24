cmake_minimum_required(VERSION 3.20)

project(brainfuck_interpreter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(brainfuck src/main.cpp)

if(MSVC)
  target_compile_options(brainfuck PRIVATE /W4 /permissive-)
else()
  target_compile_options(brainfuck PRIVATE -Wall -Wextra -Wpedantic -Wconversion)
endif()

