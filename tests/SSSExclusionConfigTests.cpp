#include "../src/SSSExclusionConfig.h"
#include <cassert>

int main()
{
    using JM::RoadEncounters::SSSExclusionConfig::ParsePluginFormValue;
    auto e = ParsePluginFormValue("pchsWartimes.esp|0x005A15");
    assert(e.has_value());
    assert(e->plugin == "pchsWartimes.esp");
    assert(e->localFormID == 0x005A15u);
    assert(!ParsePluginFormValue("bad"));
    assert(!ParsePluginFormValue("Plugin.esp|0x1000000"));
    return 0;
}
