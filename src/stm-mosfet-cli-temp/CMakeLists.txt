cmake_minimum_required(VERSION 3.22)
project(stm_mosfet_cli_temp LANGUAGES CXX)

set(I2W_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../i2w" CACHE PATH "i2w source")
set(CRAWLER_I2W_MSGS_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../crawler-i2w-msgs"
    CACHE PATH "crawler i2w messages source")

add_subdirectory("${I2W_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/i2w")
add_subdirectory("${CRAWLER_I2W_MSGS_SOURCE_DIR}"
                 "${CMAKE_CURRENT_BINARY_DIR}/crawler_i2w_msgs")

add_executable(mosfet_cli src/mosfet_cli.cpp)
target_compile_features(mosfet_cli PRIVATE cxx_std_20)
target_link_libraries(mosfet_cli PRIVATE
  i2w::i2w
  crawler_i2w_msgs::crawler_i2w_msgs
)
