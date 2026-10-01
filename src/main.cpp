#include "PCH.h"

namespace JM::RoadEncounters
{
    namespace
    {
        constexpr std::int32_t kMaximumReturnedActors = 64;
        constexpr float kMaximumRadius = 10000.0f;

        struct Candidate
        {
            float distanceSquared;
            RE::Actor* actor;
        };

        float DistanceSquared(const RE::NiPoint3& a_lhs, const RE::NiPoint3& a_rhs)
        {
            const float dx = a_lhs.x - a_rhs.x;
            const float dy = a_lhs.y - a_rhs.y;
            const float dz = a_lhs.z - a_rhs.z;
            return (dx * dx) + (dy * dy) + (dz * dz);
        }

        bool IsSameLoadedSpace(RE::TESObjectREFR* a_center, RE::Actor* a_actor)
        {
            const auto* centerWorld = a_center->GetWorldspace();
            const auto* actorWorld = a_actor->GetWorldspace();

            if (centerWorld || actorWorld) {
                return centerWorld == actorWorld;
            }

            return a_center->GetParentCell() == a_actor->GetParentCell();
        }
    }

    namespace Papyrus
    {
        constexpr auto kScriptName = "JM_RE_Native";

        bool IsAvailable(RE::StaticFunctionTag*)
        {
            return true;
        }

        std::vector<RE::Actor*> GetNearbyActors(
            RE::StaticFunctionTag*,
            RE::TESObjectREFR* a_center,
            float a_radius,
            std::int32_t a_maxResults)
        {
            std::vector<RE::Actor*> result;

            if (!a_center || a_radius <= 0.0f || a_maxResults <= 0) {
                return result;
            }

            auto* processLists = RE::ProcessLists::GetSingleton();
            if (!processLists) {
                return result;
            }

            const float radius = (std::min)(a_radius, kMaximumRadius);
            const float radiusSquared = radius * radius;
            const auto maxResults = static_cast<std::size_t>(
                (std::clamp)(a_maxResults, 1, kMaximumReturnedActors));
            const auto centerPosition = a_center->GetPosition();
            auto* player = RE::PlayerCharacter::GetSingleton();

            std::vector<Candidate> candidates;
            candidates.reserve(32);

            processLists->ForEachHighActor([&](RE::Actor* a_actor) {
                if (!a_actor ||
                    a_actor == player ||
                    a_actor == a_center ||
                    a_actor->IsDead() ||
                    a_actor->IsDisabled() ||
                    !a_actor->Is3DLoaded() ||
                    !IsSameLoadedSpace(a_center, a_actor)) {
                    return RE::BSContainer::ForEachResult::kContinue;
                }

                const float distanceSquared =
                    DistanceSquared(centerPosition, a_actor->GetPosition());

                if (distanceSquared <= radiusSquared) {
                    candidates.push_back({ distanceSquared, a_actor });
                }

                return RE::BSContainer::ForEachResult::kContinue;
            });

            if (candidates.empty()) {
                return result;
            }

            if (candidates.size() > maxResults) {
                std::partial_sort(
                    candidates.begin(),
                    candidates.begin() + static_cast<std::ptrdiff_t>(maxResults),
                    candidates.end(),
                    [](const Candidate& a_lhs, const Candidate& a_rhs) {
                        return a_lhs.distanceSquared < a_rhs.distanceSquared;
                    });
                candidates.resize(maxResults);
            } else {
                std::sort(
                    candidates.begin(),
                    candidates.end(),
                    [](const Candidate& a_lhs, const Candidate& a_rhs) {
                        return a_lhs.distanceSquared < a_rhs.distanceSquared;
                    });
            }

            result.reserve(candidates.size());
            for (const auto& candidate : candidates) {
                result.push_back(candidate.actor);
            }

            return result;
        }

        bool Register(RE::BSScript::IVirtualMachine* a_vm)
        {
            if (!a_vm) {
                return false;
            }

            a_vm->RegisterFunction("IsAvailable", kScriptName, IsAvailable);
            a_vm->RegisterFunction("GetNearbyActors", kScriptName, GetNearbyActors);

            logger::info("Registered Papyrus class {}", kScriptName);
            return true;
        }
    }

    void WakePapyrusScanner()
    {
        const auto* task = SKSE::GetTaskInterface();
        if (!task) {
            logger::error("Task interface unavailable; cannot wake JM_RE_Core");
            return;
        }

        task->AddTask([]() {
            auto* vm = RE::BSScript::Internal::VirtualMachine::GetSingleton();
            if (!vm) {
                logger::error("Papyrus VM unavailable during scanner wake");
                return;
            }

            auto* quest = RE::TESForm::LookupByEditorID<RE::TESQuest>("JM_RE_CoreQuest");
            if (!quest) {
                logger::error("JM_RE_CoreQuest not found during scanner wake");
                return;
            }

            auto* handlePolicy = vm->GetObjectHandlePolicy();
            if (!handlePolicy) {
                logger::error("Papyrus handle policy unavailable during scanner wake");
                return;
            }

            const auto handle = handlePolicy->GetHandleForObject(
                static_cast<RE::VMTypeID>(quest->GetFormType()), quest);

            RE::BSTSmartPointer<RE::BSScript::Object> scriptObject;
            if (!vm->FindBoundObject(handle, "JM_RE_Core", scriptObject) || !scriptObject) {
                logger::error("Bound JM_RE_Core script not found during scanner wake");
                return;
            }

            auto* args = RE::MakeFunctionArguments();
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> callback;

            if (!vm->DispatchMethodCall(
                    scriptObject,
                    RE::BSFixedString("NativeWakeScanner"),
                    args,
                    callback)) {
                logger::error("Failed to dispatch JM_RE_Core.NativeWakeScanner");
                return;
            }

            logger::info("Dispatched JM_RE_Core.NativeWakeScanner");
        });
    }

    void InitializeLogging()
    {
        if (const auto logDir = SKSE::log::log_directory()) {
            auto path = *logDir / "JM_RoadEncounters.log";
            auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(
                path.string(), true);
            auto log = std::make_shared<spdlog::logger>(
                "global log", std::move(sink));
            spdlog::set_default_logger(std::move(log));
            spdlog::set_level(spdlog::level::info);
            spdlog::flush_on(spdlog::level::info);
        }
    }
}

SKSEPluginLoad(const SKSE::LoadInterface* a_skse)
{
    SKSE::Init(a_skse);
    JM::RoadEncounters::InitializeLogging();

    logger::info("JM_RoadEncounters native detector loading");

    const auto runtime = REL::Module::get().version();
    if (runtime != SKSE::RUNTIME_SSE_1_5_97) {
        logger::critical(
            "Unsupported Skyrim runtime {}. JM_RoadEncounters is intentionally built for 1.5.97.",
            runtime.string());
        return false;
    }

    const auto* papyrus = SKSE::GetPapyrusInterface();
    if (!papyrus) {
        logger::critical("SKSE Papyrus interface unavailable");
        return false;
    }

    if (!papyrus->Register(JM::RoadEncounters::Papyrus::Register)) {
        logger::critical("Failed to register JM_RE_Native Papyrus functions");
        return false;
    }

    const auto* messaging = SKSE::GetMessagingInterface();
    if (!messaging) {
        logger::critical("SKSE messaging interface unavailable");
        return false;
    }

    if (!messaging->RegisterListener([](SKSE::MessagingInterface::Message* a_message) {
            if (!a_message) {
                return;
            }

            if (a_message->type == SKSE::MessagingInterface::kPostLoadGame ||
                a_message->type == SKSE::MessagingInterface::kNewGame) {
                JM::RoadEncounters::WakePapyrusScanner();
            }
        })) {
        logger::critical("Failed to register SKSE message listener");
        return false;
    }

    logger::info("JM_RoadEncounters native detector loaded successfully");
    return true;
}
