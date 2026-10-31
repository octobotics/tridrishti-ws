#include <charconv>
#include <chrono>
#include <cstdio>
#include <string_view>
#include <thread>
#include <utility>

#include "crawler_i2w_services/channelSwitching.hpp"
#include "i2w/impl.hpp"

namespace {

using Request = crawler_i2w_services::SetChannelStatusRequest;
using Response = crawler_i2w_services::SetChannelStatusResponse;

class MosfetCli final : public i2w::SystemBase {
 public:
  MosfetCli(i2w::Config config, int id, bool on)
      : i2w::SystemBase(std::move(config)), id_(id), on_(on) {}

  bool finished() const { return finished_; }
  bool succeeded() const { return succeeded_; }

 private:
  i2w::LifecycleResult OnSetup() override {
    auto client = runtime().create_client<Request, Response>("/set_mosfet_service");
    if (!client) {
      std::fprintf(stderr, "could not create MOSFET service client: %s\n",
                   i2w::to_string(client.error()));
      return i2w::Fail();
    }
    client_ = std::move(client.value());
    return i2w::Ok();
  }

  i2w::LifecycleResult OnTick() override {
    if (sent_ || finished_) return i2w::Ok();

    Request request{};
    request.device_id = static_cast<std::int8_t>(id_);
    request.status = on_;
    auto result = client_.call(request, runtime().clock().now().ns,
                               [this](const auto& sample) {
      finished_ = true;
      succeeded_ = sample.value.result && sample.value.device_id == id_;
      if (succeeded_) {
        std::printf("MOSFET %d %s command accepted by STM node\n",
                    id_, on_ ? "on" : "off");
      } else {
        std::fprintf(stderr, "MOSFET %d %s command rejected by STM node\n",
                     id_, on_ ? "on" : "off");
      }
    });
    if (result) sent_ = true;
    return i2w::Ok();
  }

  int id_;
  bool on_;
  bool sent_{false};
  bool finished_{false};
  bool succeeded_{false};
  i2w::Client<Request, Response> client_{};
};

}  // namespace

int main(int argc, char** argv) {
  if (argc != 3) {
    std::fprintf(stderr, "usage: mosfet_cli <id: 1-7> <on|off>\n");
    return 1;
  }
  const std::string_view id_text{argv[1]};
  int id = 0;
  const auto [end, error] = std::from_chars(id_text.data(),
                                            id_text.data() + id_text.size(), id);
  const std::string_view state{argv[2]};
  if (error != std::errc{} || end != id_text.data() + id_text.size() ||
      id < 1 || id > 7 || (state != "on" && state != "off")) {
    std::fprintf(stderr, "usage: mosfet_cli <id: 1-7> <on|off>\n");
    return 1;
  }

  i2w::Config config;
  config.node_name = "mosfet_cli";
  MosfetCli app(std::move(config), id, state == "on");
  if (!app.Setup().ok) return 2;
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(8);
  while (!app.finished() && std::chrono::steady_clock::now() < deadline) {
    if (!app.Tick().ok) return 2;
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
  }
  if (!app.finished()) {
    std::fprintf(stderr, "MOSFET service unavailable or response timed out\n");
    return 3;
  }
  return app.succeeded() ? 0 : 4;
}
