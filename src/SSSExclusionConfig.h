#pragma once

#include <charconv>
#include <cctype>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>

namespace JM::RoadEncounters::SSSExclusionConfig
{
    struct Entry
    {
        std::string plugin;
        std::uint32_t localFormID{ 0 };
    };

    inline std::string_view TrimView(std::string_view a_value)
    {
        while (!a_value.empty() && std::isspace(static_cast<unsigned char>(a_value.front()))) {
            a_value.remove_prefix(1);
        }
        while (!a_value.empty() && std::isspace(static_cast<unsigned char>(a_value.back()))) {
            a_value.remove_suffix(1);
        }
        return a_value;
    }

    inline std::optional<Entry> ParsePluginFormValue(std::string_view a_value)
    {
        a_value = TrimView(a_value);
        const auto separator = a_value.find('|');
        if (separator == std::string_view::npos || separator == 0 || separator + 1 >= a_value.size()) {
            return std::nullopt;
        }

        auto pluginView = TrimView(a_value.substr(0, separator));
        auto idView = TrimView(a_value.substr(separator + 1));
        if (pluginView.empty() || idView.empty()) {
            return std::nullopt;
        }

        int base = 10;
        if (idView.size() > 2 && idView[0] == '0' && (idView[1] == 'x' || idView[1] == 'X')) {
            base = 16;
            idView.remove_prefix(2);
        }
        if (idView.empty()) {
            return std::nullopt;
        }

        std::uint32_t localFormID = 0;
        const char* first = idView.data();
        const char* last = first + idView.size();
        const auto [ptr, ec] = std::from_chars(first, last, localFormID, base);
        if (ec != std::errc{} || ptr != last || localFormID > 0x00FFFFFFu) {
            return std::nullopt;
        }

        return Entry{ std::string(pluginView), localFormID };
    }
}
