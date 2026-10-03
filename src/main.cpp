#include "PCH.h"

namespace JM::RoadEncounters
{
    namespace
    {
        constexpr std::int32_t kMaximumReturnedActors = 64;
        constexpr float kMaximumRadius = 10000.0f;

        // SSS_Whoring uses four idle INFOs as its authoritative eligibility
        // rules.  The native scanner evaluates those *actual loaded INFO
        // conditions* against a candidate actor, so JM does not duplicate
        // fragile faction / sex / amulet / distance / player-state logic in
        // Papyrus.  Alias indices are from the original SSS_Whoring quest.
        struct SSSApproachRule
        {
            std::uint32_t localInfoFormID;
            std::int32_t aliasIndex;
            const char* label;
        };

        constexpr std::array<SSSApproachRule, 4> kSSSApproachRules{{
            { 0x00D471B9, 0, "client" },   // SSS_SoliciteforSex -> akClient
            { 0x00E904EB, 3, "soldier" },  // SSS_SoldierWhore -> akSoldier
            { 0x00E7C0DF, 2, "amulet" },   // SSS_AmuletSex -> akJill
            { 0x00F13F73, 5, "bandit" }    // SSS_BanditApproach -> akBandit
        }};

        struct SSSAliasPackage
        {
            std::int32_t aliasIndex;
            std::uint32_t localPackageFormID;
        };

        constexpr std::array<SSSAliasPackage, 4> kSSSAliasPackages{{
            { 0, 0x00D420AE },  // SSS_SolicitePlayerPackage
            { 2, 0x00EA9A0B },  // SSS_SolicitePlayerPackageGigolo
            { 3, 0x00E904EA },  // SSS_SoldierSolicitePlayerPackage
            { 5, 0x00F1E176 }   // SSS_BanditrSolicitePlayerPackage
        }};

        constexpr std::uint32_t kSSSForceGreetTemplate = 0x00D471B7;

        std::shared_ptr<spdlog::logger> g_sssLogger;

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

        std::vector<RE::Actor*> MakeNoResultArray(RE::Actor* a_player)
        {
            // CommonLib/Papyrus represents an empty native std::vector as None
            // on this runtime.  Assigning that to Actor[] produces the noisy
            // "Cannot cast from None to Actor[]" / temp-variable errors seen
            // in JMEE.  A single PlayerRef sentinel forces creation of a real,
            // typed Actor[]; every consumer already excludes the player.
            std::vector<RE::Actor*> result;
            if (a_player) {
                result.push_back(a_player);
            }
            return result;
        }

        std::int32_t ClassifySSSWhoringActorImpl(RE::Actor* a_actor)
        {
            auto* player = RE::PlayerCharacter::GetSingleton();
            if (!player || !a_actor || a_actor == player ||
                a_actor->IsDead() || a_actor->IsDisabled() ||
                !a_actor->Is3DLoaded()) {
                return -1;
            }

            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!dataHandler) {
                if (g_sssLogger) {
                    g_sssLogger->error("classification failed: TESDataHandler unavailable");
                }
                return -1;
            }

            // Evaluate in the original INFO order.  The winning INFO object
            // contains the current override's CTDA chain, including JM's
            // ReadyGlobal condition, so this automatically tracks xEdit
            // changes without re-implementing them in C++.
            for (const auto& rule : kSSSApproachRules) {
                auto* info = dataHandler->LookupForm<RE::TESTopicInfo>(
                    rule.localInfoFormID, "SkyrimShroudedSecret.esp");
                if (!info) {
                    if (g_sssLogger) {
                        g_sssLogger->error(
                            "missing SSS_WhoringIdle INFO 0x{:06X} ({})",
                            rule.localInfoFormID, rule.label);
                    }
                    continue;
                }

                if (info->objConditions.IsTrue(a_actor, player)) {
                    if (g_sssLogger) {
                        g_sssLogger->info(
                            "eligible actor={} form=0x{:08X} rule={} alias={} distance={:.0f}",
                            a_actor->GetName(),
                            a_actor->GetFormID(),
                            rule.label,
                            rule.aliasIndex,
                            a_actor->GetDistance(player));
                    }
                    return rule.aliasIndex;
                }
            }

            return -1;
        }

        bool IsSSSWhoringPackageActiveImpl(
            RE::Actor* a_actor,
            std::int32_t a_aliasIndex)
        {
            if (!a_actor) {
                return false;
            }

            auto* current = a_actor->GetCurrentPackage();
            auto* dataHandler = RE::TESDataHandler::GetSingleton();
            if (!current || !dataHandler) {
                return false;
            }

            auto* forceGreetTemplate = dataHandler->LookupForm<RE::TESPackage>(
                kSSSForceGreetTemplate, "SkyrimShroudedSecret.esp");
            if (current == forceGreetTemplate) {
                return true;
            }

            for (const auto& entry : kSSSAliasPackages) {
                if (entry.aliasIndex != a_aliasIndex) {
                    continue;
                }

                auto* expected = dataHandler->LookupForm<RE::TESPackage>(
                    entry.localPackageFormID,
                    "SkyrimShroudedSecret.esp");
                return current == expected;
            }

            return false;
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
            auto* player = RE::PlayerCharacter::GetSingleton();

            if (!a_center || a_radius <= 0.0f || a_maxResults <= 0) {
                return MakeNoResultArray(player);
            }

            auto* processLists = RE::ProcessLists::GetSingleton();
            if (!processLists) {
                return MakeNoResultArray(player);
            }

            const float radius = (std::min)(a_radius, kMaximumRadius);
            const float radiusSquared = radius * radius;
            const auto maxResults = static_cast<std::size_t>(
                (std::clamp)(a_maxResults, 1, kMaximumReturnedActors));
            const auto centerPosition = a_center->GetPosition();

            std::vector<Candidate> candidates;
            candidates.reserve(32);

            processLists->ForEachHighActor([&](RE::Actor& a_actorRef) {
                auto* a_actor = std::addressof(a_actorRef);

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
                return MakeNoResultArray(player);
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

            if (result.empty()) {
                return MakeNoResultArray(player);
            }
            return result;
        }

        std::int32_t ClassifySSSWhoringActor(
            RE::StaticFunctionTag*,
            RE::Actor* a_actor)
        {
            return ClassifySSSWhoringActorImpl(a_actor);
        }

        RE::Actor* FindSSSWhoringActor(
            RE::StaticFunctionTag*,
            RE::TESObjectREFR* a_center,
            float a_radius,
            std::int32_t a_maxResults)
        {
            const auto nearby =
                GetNearbyActors(nullptr, a_center, a_radius, a_maxResults);
            auto* player = RE::PlayerCharacter::GetSingleton();

            std::int32_t tested = 0;
            for (auto* actor : nearby) {
                if (!actor || actor == player) {
                    continue;  // PlayerRef is the typed-array no-result sentinel.
                }

                ++tested;
                const auto aliasIndex = ClassifySSSWhoringActorImpl(actor);
                if (aliasIndex >= 0) {
                    if (g_sssLogger) {
                        g_sssLogger->info(
                            "acquisition selected actor={} form=0x{:08X} "
                            "alias={} tested={} radius={:.0f}",
                            actor->GetName(),
                            actor->GetFormID(),
                            aliasIndex,
                            tested,
                            a_radius);
                    }
                    return actor;
                }
            }

            static std::atomic<std::uint64_t> noCandidateScans{ 0 };
            const auto scan = ++noCandidateScans;
            if (g_sssLogger && (scan % 10) == 0) {
                g_sssLogger->info(
                    "acquisition scan #{} found no eligible SSS actor "
                    "(tested={}, radius={:.0f})",
                    scan, tested, a_radius);
            }
            return nullptr;
        }

        bool IsSSSWhoringPackageActive(
            RE::StaticFunctionTag*,
            RE::Actor* a_actor,
            std::int32_t a_aliasIndex)
        {
            return IsSSSWhoringPackageActiveImpl(a_actor, a_aliasIndex);
        }

        bool IsSSSWhoringDialogueActive(
            RE::StaticFunctionTag*,
            RE::Actor* a_actor)
        {
            if (!a_actor) {
                return false;
            }

            auto* manager = RE::MenuTopicManager::GetSingleton();
            auto* quest = RE::TESForm::LookupByEditorID<RE::TESQuest>("SSS_Whoring");
            if (!manager || !quest) {
                return false;
            }

            const auto actorHandle = a_actor->GetHandle().native_handle();
            const auto speakerHandle = manager->speaker.native_handle();
            auto* info = manager->currentTopicInfo;

            const bool active =
                actorHandle != 0 &&
                actorHandle == speakerHandle &&
                info != nullptr &&
                info->parentTopic != nullptr &&
                info->parentTopic->ownerQuest == quest;

            if (active && g_sssLogger) {
                g_sssLogger->info(
                    "verified live SSS dialogue speaker={} form=0x{:08X} "
                    "topicInfo=0x{:08X}",
                    a_actor->GetName(),
                    a_actor->GetFormID(),
                    info->GetFormID());
            }
            return active;
        }

        bool Register(RE::BSScript::IVirtualMachine* a_vm)
        {
            if (!a_vm) {
                return false;
            }

            a_vm->RegisterFunction("IsAvailable", kScriptName, IsAvailable);
            a_vm->RegisterFunction("GetNearbyActors", kScriptName, GetNearbyActors);
            a_vm->RegisterFunction(
                "ClassifySSSWhoringActor",
                kScriptName,
                ClassifySSSWhoringActor);
            a_vm->RegisterFunction(
                "FindSSSWhoringActor",
                kScriptName,
                FindSSSWhoringActor);
            a_vm->RegisterFunction(
                "IsSSSWhoringPackageActive",
                kScriptName,
                IsSSSWhoringPackageActive);
            a_vm->RegisterFunction(
                "IsSSSWhoringDialogueActive",
                kScriptName,
                IsSSSWhoringDialogueActive);

            logger::info("Registered Papyrus class {}", kScriptName);
            if (g_sssLogger) {
                g_sssLogger->info(
                    "native SSS acquisition API registered on {}",
                    kScriptName);
            }
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

            if (!vm->DispatchMethodCall1(
                    scriptObject,
                    RE::BSFixedString("NativeWakeScanner"),
                    args,
                    callback)) {
                logger::error("Failed to dispatch JM_RE_Core.NativeWakeScanner");
                return;
            }

            logger::info("Dispatched JM_RE_Core.NativeWakeScanner");

            // Skyrim Shrouded Secret is optional.  If present, wake JM's
            // acquisition controller on every load/new game so it reconciles
            // its save-persistent cooldown and immediately re-arms scanning.
            auto* sssQuest = RE::TESForm::LookupByEditorID<RE::TESQuest>("SSS_Whoring");
            if (!sssQuest) {
                if (g_sssLogger) {
                    g_sssLogger->info("SSS_Whoring not installed; native SSS wake skipped");
                }
                return;
            }

            const auto sssHandle = handlePolicy->GetHandleForObject(
                static_cast<RE::VMTypeID>(sssQuest->GetFormType()), sssQuest);

            RE::BSTSmartPointer<RE::BSScript::Object> sssScriptObject;
            if (!vm->FindBoundObject(
                    sssHandle,
                    "JM_SSS_WhoringController",
                    sssScriptObject) ||
                !sssScriptObject) {
                if (g_sssLogger) {
                    g_sssLogger->warn(
                        "SSS_Whoring is present but JM_SSS_WhoringController "
                        "is not bound; acquisition wake skipped");
                }
                return;
            }

            auto* sssArgs = RE::MakeFunctionArguments();
            RE::BSTSmartPointer<RE::BSScript::IStackCallbackFunctor> sssCallback;
            if (!vm->DispatchMethodCall1(
                    sssScriptObject,
                    RE::BSFixedString("NativeWakeScanner"),
                    sssArgs,
                    sssCallback)) {
                if (g_sssLogger) {
                    g_sssLogger->error(
                        "failed to dispatch JM_SSS_WhoringController.NativeWakeScanner");
                }
                return;
            }

            if (g_sssLogger) {
                g_sssLogger->info(
                    "dispatched JM_SSS_WhoringController.NativeWakeScanner");
            }
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

            auto sssPath = *logDir / "JM_SSS_Native.log";
            auto sssSink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(
                sssPath.string(), true);
            g_sssLogger = std::make_shared<spdlog::logger>(
                "jm_sss_native", std::move(sssSink));
            g_sssLogger->set_level(spdlog::level::info);
            g_sssLogger->flush_on(spdlog::level::info);
            spdlog::register_logger(g_sssLogger);
            g_sssLogger->info("JM SSS native acquisition diagnostics initialized");
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
