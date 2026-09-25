import Foundation

struct TestFailure: Error, CustomStringConvertible {
    var description: String
}

func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    if actual != expected {
        recordFailure("expected \(expected), got \(actual)", file: file, line: line)
    }
}

func XCTAssertTrue(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    if !condition() {
        recordFailure("expected true", file: file, line: line)
    }
}

func XCTAssertFalse(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    if condition() {
        recordFailure("expected false", file: file, line: line)
    }
}

func XCTAssertNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #file, line: UInt = #line) {
    if let value = value() {
        recordFailure("expected nil, got \(value)", file: file, line: line)
    }
}

func XCTAssertNotNil<T>(_ value: @autoclosure () -> T?, file: StaticString = #file, line: UInt = #line) {
    if value() == nil {
        recordFailure("expected non-nil", file: file, line: line)
    }
}

func XCTAssertContains(_ value: String, _ expectedSubstring: String, file: StaticString = #file, line: UInt = #line) {
    if !value.contains(expectedSubstring) {
        recordFailure("expected \(value) to contain \(expectedSubstring)", file: file, line: line)
    }
}

private var failures: [String] = []

func recordFailure(_ message: String, file: StaticString, line: UInt) {
    failures.append("\(file):\(line): \(message)")
}

func run(_ name: String, _ body: () throws -> Void) {
    let before = failures.count
    do {
        try body()
    } catch {
        failures.append("\(name): threw \(error)")
    }
    if failures.count == before {
        print("ok - \(name)")
    } else {
        print("not ok - \(name)")
    }
}

let config = SetupConfigurationTests()
run("testOutputAppPathAddsAppSuffix", config.testOutputAppPathAddsAppSuffix)
run("testOutputAppPathDoesNotDuplicateAppSuffix", config.testOutputAppPathDoesNotDuplicateAppSuffix)
run("testDefaultOutputAppPathUsesApplicationsFolder", config.testDefaultOutputAppPathUsesApplicationsFolder)
run("testWrapperNameValidationRejectsUnsafeNames", config.testWrapperNameValidationRejectsUnsafeNames)
run("testEnvironmentOKRequiresAnExistingModOrganizerExecutable", config.testEnvironmentOKRequiresAnExistingModOrganizerExecutable)
run("testLaunchExecutableFallsBackToBareModOrganizerName", config.testLaunchExecutableFallsBackToBareModOrganizerName)
run("testCustomLaunchExecutableIsResolvedThroughItsBatch", config.testCustomLaunchExecutableIsResolvedThroughItsBatch)
run("testCustomLaunchExecutableMustStillExist", config.testCustomLaunchExecutableMustStillExist)
run("testDriveMappingIsDerivedFromTheResolvedLaunchTarget", config.testDriveMappingIsDerivedFromTheResolvedLaunchTarget)
run("testDriveMappingIsNotReadyWithoutAResolvedLaunchTarget", config.testDriveMappingIsNotReadyWithoutAResolvedLaunchTarget)

let appSettings = AppSettingsStoreTests()
run("testModOrganizerValidationRequiresExecutableNameAndFile", appSettings.testModOrganizerValidationRequiresExecutableNameAndFile)
run("testAppSettingsSaveAndLoadRoundTripsGammaPath", appSettings.testAppSettingsSaveAndLoadRoundTripsGammaPath)
run("testAppSettingsLoadIgnoresMissingAndMalformedFiles", appSettings.testAppSettingsLoadIgnoresMissingAndMalformedFiles)
run("testEnsureSettingsFileExistsCreatesDefaultJson", appSettings.testEnsureSettingsFileExistsCreatesDefaultJson)
run("testEnsureSettingsFileExistsDoesNotOverwriteAnExistingFile", appSettings.testEnsureSettingsFileExistsDoesNotOverwriteAnExistingFile)

let redist = RedistInstallerTests()
run("testRequestWithoutARedistDirectoryStillDecodes", redist.testRequestWithoutARedistDirectoryStillDecodes)
run("testRequestRoundTripsASuppliedRedistDirectory", redist.testRequestRoundTripsASuppliedRedistDirectory)
run("testRequestRoundTripsALogFile", redist.testRequestRoundTripsALogFile)
run("testEveryPinnedInstallerIsReportedOnce", redist.testEveryPinnedInstallerIsReportedOnce)
run("testCachedInstallersAreReportedAsPresent", redist.testCachedInstallersAreReportedAsPresent)
run("testASuppliedDirectoryWinsOverTheCache", redist.testASuppliedDirectoryWinsOverTheCache)

let engineArchive = EngineArchiveTests()
run("testComparatorOrdersByCrossoverThenWineThenGammaThenBuild", engineArchive.testComparatorOrdersByCrossoverThenWineThenGammaThenBuild)
run("testComparatorTreatsShortAndLongCrossoverFormsAsEqual", engineArchive.testComparatorTreatsShortAndLongCrossoverFormsAsEqual)
run("testEqualityIgnoresFamilyAndLabelByDesign", engineArchive.testEqualityIgnoresFamilyAndLabelByDesign)
run("testParseLabelHandlesTheVersionLabelForm", engineArchive.testParseLabelHandlesTheVersionLabelForm)
run("testParseLabelHandlesTheEngineIdSlugForm", engineArchive.testParseLabelHandlesTheEngineIdSlugForm)
run("testParseLabelRejectsGarbage", engineArchive.testParseLabelRejectsGarbage)
run("testParseBuildCounterFromCurrentAndLegacyNames", engineArchive.testParseBuildCounterFromCurrentAndLegacyNames)
run("testVersionPrefersManifestBuildNumberOverName", engineArchive.testVersionPrefersManifestBuildNumberOverName)
run("testVersionFallsBackToNameWhenNoBuildNumber", engineArchive.testVersionFallsBackToNameWhenNoBuildNumber)
run("testVersionRefusesRatherThanGuessingBuildZero", engineArchive.testVersionRefusesRatherThanGuessingBuildZero)
run("testDecodesTheInArchiveManifestShape", engineArchive.testDecodesTheInArchiveManifestShape)
run("testDecodesTheSidecarManifestShape", engineArchive.testDecodesTheSidecarManifestShape)
run("testRejectsAnUnsupportedSchemaVersion", engineArchive.testRejectsAnUnsupportedSchemaVersion)
run("testEveryFieldExceptSchemaVersionIsOptional", engineArchive.testEveryFieldExceptSchemaVersionIsOptional)
run("testFloorFromLiveAndNoCache", engineArchive.testFloorFromLiveAndNoCache)
run("testFloorFromLiveOlderThanCacheStillUsesTheHigherCache", engineArchive.testFloorFromLiveOlderThanCacheStillUsesTheHigherCache)
run("testFloorFromCacheOnlyWhenLiveUnavailable", engineArchive.testFloorFromCacheOnlyWhenLiveUnavailable)
run("testFloorFallsBackToCompiledMinimumWithNoLiveAndNoCache", engineArchive.testFloorFallsBackToCompiledMinimumWithNoLiveAndNoCache)
run("testFloorNeverDropsBelowTheCompiledMinimumEvenIfCacheIsSomehowOlder", engineArchive.testFloorNeverDropsBelowTheCompiledMinimumEvenIfCacheIsSomehowOlder)
run("testFloorNamesTheCompiledMinimumWhenItOutranksTheLiveRelease", engineArchive.testFloorNamesTheCompiledMinimumWhenItOutranksTheLiveRelease)
run("testFloorCacheOnlyEverMovesUp", engineArchive.testFloorCacheOnlyEverMovesUp)
run("testFloorFromASubstituteListingIsNotCached", engineArchive.testFloorFromASubstituteListingIsNotCached)
run("testCompiledMinimumIsExpressedInTheCurrentGenerationSoBuildZeroIsRefused", engineArchive.testCompiledMinimumIsExpressedInTheCurrentGenerationSoBuildZeroIsRefused)
run("testAcceptsAnArchiveAtOrAboveTheFloor", engineArchive.testAcceptsAnArchiveAtOrAboveTheFloor)
run("testRefusesAnArchiveBelowTheFloorWithNoOverride", engineArchive.testRefusesAnArchiveBelowTheFloorWithNoOverride)
run("testAcceptsANewerLocalBuildAboveTheFloor", engineArchive.testAcceptsANewerLocalBuildAboveTheFloor)
run("testRefusesAnArchiveNeedingANewerMacOS", engineArchive.testRefusesAnArchiveNeedingANewerMacOS)
run("testAcceptsWhenThisMacMeetsTheRequiredMacOS", engineArchive.testAcceptsWhenThisMacMeetsTheRequiredMacOS)
run("testRefusesAnArchiveNeedingANewerSetupTool", engineArchive.testRefusesAnArchiveNeedingANewerSetupTool)
run("testAcceptsAnEqualVersionNotOnlyNewer", engineArchive.testAcceptsAnEqualVersionNotOnlyNewer)
run("testRefusesRatherThanGuessingWhenTheManifestLabelIsUnreadable", engineArchive.testRefusesRatherThanGuessingWhenTheManifestLabelIsUnreadable)
run("testPicksTheNewestEngineReleaseByVersionNotArrayOrder", engineArchive.testPicksTheNewestEngineReleaseByVersionNotArrayOrder)
run("testIgnoresReleasesWithoutTheEngineTagPrefix", engineArchive.testIgnoresReleasesWithoutTheEngineTagPrefix)
run("testIgnoresAMalformedReleaseMissingSidecarAssets", engineArchive.testIgnoresAMalformedReleaseMissingSidecarAssets)
run("testThrowsWhenNoEngineReleaseExists", engineArchive.testThrowsWhenNoEngineReleaseExists)
run("testProbeReadsATarXzArchive", engineArchive.testProbeReadsATarXzArchive)
run("testProbeReadsATarZstArchiveWithAFinderLikePath", engineArchive.testProbeReadsATarZstArchiveWithAFinderLikePath)
run("testProbeRefusesAZstArchiveClearlyWhenZstdIsMissing", engineArchive.testProbeRefusesAZstArchiveClearlyWhenZstdIsMissing)
run("testToolVersionMatchesBuildScriptAppVersion", engineArchive.testToolVersionMatchesBuildScriptAppVersion)

let usvfs = USVFSUpdaterTests()
run("testUSVFSDefaultSourceIsNotUserSpecific", usvfs.testUSVFSDefaultSourceIsNotUserSpecific)
run("testNonModOrganizerFolderIsLeftUntouched", usvfs.testNonModOrganizerFolderIsLeftUntouched)
run("testMatchingBinariesAreNotRewrittenOrBackedUp", usvfs.testMatchingBinariesAreNotRewrittenOrBackedUp)
run("testDifferingBinariesAreBackedUpThenReplaced", usvfs.testDifferingBinariesAreBackedUpThenReplaced)
run("testMissingBinariesAreInstalledWithoutABackup", usvfs.testMissingBinariesAreInstalledWithoutABackup)
run("testRepeatedUpdatesKeepEarlierBackups", usvfs.testRepeatedUpdatesKeepEarlierBackups)
run("testModOrganizerDetectionIgnoresLetterCase", usvfs.testModOrganizerDetectionIgnoresLetterCase)

let relay = ScriptOutputRelayTests()
run("testHoldsBackTheScriptsCompletedEventButKeepsItsFailure", relay.testHoldsBackTheScriptsCompletedEventButKeepsItsFailure)
run("testIgnoresASuccessfulCompletedEvent", relay.testIgnoresASuccessfulCompletedEvent)
run("testRelaysLinesSplitAcrossChunksAndAFinalUnterminatedLine", relay.testRelaysLinesSplitAcrossChunksAndAFinalUnterminatedLine)
run("testStopsAcceptingOutputAfterFinish", relay.testStopsAcceptingOutputAfterFinish)

let tones = SetupStatusToneTests()
run("testCheckRowTonesMatchEnvironmentColoringRules", tones.testCheckRowTonesMatchEnvironmentColoringRules)
run("testStatusRowTonesMatchCheckRows", tones.testStatusRowTonesMatchCheckRows)

if failures.isEmpty {
    print("\nAll Swift tests passed.")
} else {
    for failure in failures {
        print(failure)
    }
    exit(1)
}
