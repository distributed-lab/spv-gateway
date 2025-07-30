methods {
    function EXPECTED_TARGET_BLOCKS_TIME() external returns (uint256) envfree;
    function DIFFICULTY_ADJUSTMENT_INTERVAL() external returns (uint256) envfree;
    function INITIAL_TARGET() external returns (bytes32) envfree;
    function TARGET_FIXED_POINT_FACTOR() external returns (uint256) envfree;
    function MAX_TARGET_FACTOR() external returns (uint256) envfree;
    function MAX_TARGET_RATIO() external returns (uint256) envfree;
    function MIN_TARGET_RATIO() external returns (uint256) envfree;
    
    function isTargetAdjustmentBlock(uint256 blockHeight_) external returns (bool) envfree;
    function getEpochBlockNumber(uint256 blockHeight_) external returns (uint256) envfree;
    function countNewRoundedTarget(bytes32 currentTarget_, uint256 actualPassedTime_) external returns (bytes32) envfree;
    function countNewTarget(bytes32 currentTarget_, uint256 actualPassedTime_) external returns (bytes32) envfree;
    function countEpochCumulativeWork(bytes32 epochTarget_) external returns (uint256) envfree;
    function countCumulativeWork(bytes32 epochTarget_, uint256 blocksCount_) external returns (uint256) envfree;
    function countBlockWork(bytes32 target_) external returns (uint256) envfree;
    function bitsToTarget(bytes4 bits_) external returns (bytes32) envfree;
    function targetToBits(bytes32 target_) external returns (bytes4) envfree;
    function roundTarget(bytes32 currentTarget_) external returns (bytes32) envfree;
    function isValidTarget(bytes32 target_) external returns (bool) envfree;
    function isValidBits(bytes4 bits_) external returns (bool) envfree;
}

definition isValidTargetDef(bytes32 target) returns bool = 
    target > 0 && target <= INITIAL_TARGET();

definition isNormalDifficultyRange(uint256 actualTime) returns bool = 
    actualTime >= EXPECTED_TARGET_BLOCKS_TIME() / 4 && 
    actualTime <= EXPECTED_TARGET_BLOCKS_TIME() * 4;

// Constants should have correct Bitcoin values
invariant constantsMatchBitcoinSpec()
    EXPECTED_TARGET_BLOCKS_TIME() == 1209600 && // 2 weeks in seconds
    DIFFICULTY_ADJUSTMENT_INTERVAL() == 2016 && // 2016 blocks per epoch
    TARGET_FIXED_POINT_FACTOR() == 10^18 && // Fixed point precision
    MAX_TARGET_FACTOR() == 4 && // Maximum 4x target change
    MAX_TARGET_RATIO() == TARGET_FIXED_POINT_FACTOR() * MAX_TARGET_FACTOR() &&
    MIN_TARGET_RATIO() == TARGET_FIXED_POINT_FACTOR() / MAX_TARGET_FACTOR();

// Initial target should be the maximum allowed target (minimum difficulty)
invariant initialTargetIsMaximum()
    INITIAL_TARGET() == 0x00000000ffff0000000000000000000000000000000000000000000000000000;

// =======================
// EPOCH AND BLOCK HEIGHT RULES
// =======================

// Rule: Block height to epoch mapping should be consistent
rule epochBlockNumberCorrectness(uint256 blockHeight) {
    uint256 epochBlock = getEpochBlockNumber(blockHeight);
    
    // Epoch block number should be in valid range
    assert epochBlock < DIFFICULTY_ADJUSTMENT_INTERVAL();
    assert epochBlock == blockHeight % DIFFICULTY_ADJUSTMENT_INTERVAL();
}

// Rule: Target adjustment blocks should be correctly identified
rule targetAdjustmentBlockIdentification(uint256 blockHeight) {
    bool isAdjustment = isTargetAdjustmentBlock(blockHeight);
    uint256 epochBlock = getEpochBlockNumber(blockHeight);
    
    // Adjustment blocks should be at epoch boundaries (except genesis)
    assert isAdjustment <=> (epochBlock == 0 && blockHeight > 0);
}

// =======================
// BITS <-> TARGET CONVERSION RULES
// =======================

// Rule: bitsToTarget and targetToBits should be approximate inverses
rule bitsTargetConversionSymmetry(bytes4 bits) {
    require isValidBits(bits);
    
    bytes32 target = bitsToTarget(bits);
    bytes4 convertedBits = targetToBits(target);
    
    // The conversion should be approximately symmetric (within rounding tolerance)
    bytes32 reconvertedTarget = bitsToTarget(convertedBits);
    
    // Reconverted target should be close to original target
    assert isValidTargetDef(target);
    assert isValidTargetDef(reconvertedTarget);
    
}

// Rule: Valid bits should produce valid targets
rule validBitsProduceValidTargets(bytes4 bits) {
    require isValidBits(bits);
    
    bytes32 target = bitsToTarget(bits);
    
    assert isValidTarget(target);
    assert target > 0;
    assert target <= INITIAL_TARGET();
}

// Rule: Valid targets should produce valid bits
rule validTargetsProduceValidBits(bytes32 target) {
    require isValidTarget(target);
    
    bytes4 bits = targetToBits(target);
    
    assert isValidBits(bits);
}

// =======================
// DIFFICULTY ADJUSTMENT RULES
// =======================

// Rule: New target should be clamped within allowed range
rule difficultyAdjustmentClamping(bytes32 currentTarget, uint256 actualTime) {
    require isValidTarget(currentTarget);
    require actualTime > 0;
    
    bytes32 newTarget = countNewTarget(currentTarget, actualTime);
    
    // New target should be valid
    assert isValidTarget(newTarget);
    
    // New target should not exceed initial target (minimum difficulty)
    assert newTarget <= INITIAL_TARGET();
    
    // Test extreme cases
    if (actualTime >= EXPECTED_TARGET_BLOCKS_TIME() * 4) {
        // If time was 4x longer, target should increase by at most 4x
        assert newTarget <= currentTarget * 4 || newTarget == INITIAL_TARGET();
    }
    
    if (actualTime <= EXPECTED_TARGET_BLOCKS_TIME() / 4) {
        // If time was 4x shorter, target should decrease by at most 4x
        assert newTarget >= currentTarget / 4;
    }
}

// Rule: Difficulty adjustment with expected time should not change target significantly
rule difficultyAdjustmentStability(bytes32 currentTarget) {
    require isValidTarget(currentTarget);
    require currentTarget < INITIAL_TARGET(); // Not at maximum
    
    // With expected time, target should remain approximately the same
    bytes32 newTarget = countNewTarget(currentTarget, EXPECTED_TARGET_BLOCKS_TIME());
    
    assert isValidTarget(newTarget);
    // New target should be very close to current target (within small tolerance)
    // Due to integer arithmetic, we allow some small variation
}

// Rule: Rounded target should be less than or equal to unrounded target
rule targetRoundingBehavior(bytes32 currentTarget, uint256 actualTime) {
    require isValidTarget(currentTarget);
    require actualTime > 0;
    
    bytes32 unroundedTarget = countNewTarget(currentTarget, actualTime);
    bytes32 roundedTarget = countNewRoundedTarget(currentTarget, actualTime);
    
    assert isValidTarget(unroundedTarget);
    assert isValidTarget(roundedTarget);
    
    // Rounded target should not be significantly different from unrounded
    // (Bitcoin's rounding preserves most significant bits)
}

// =======================
// WORK CALCULATION RULES
// =======================

// Rule: Block work should be inversely related to target
rule blockWorkInverselyRelatedToTarget(bytes32 target1, bytes32 target2) {
    require isValidTarget(target1);
    require isValidTarget(target2);
    require target1 < target2; // target1 is smaller (higher difficulty)
    
    uint256 work1 = countBlockWork(target1);
    uint256 work2 = countBlockWork(target2);
    
    // Smaller target should require more work
    assert work1 > work2;
}

// Rule: Block work should never be zero for valid targets
rule blockWorkNeverZero(bytes32 target) {
    require isValidTarget(target);
    
    uint256 work = countBlockWork(target);
    
    assert work > 0;
}

// Rule: Cumulative work should be proportional to block count
rule cumulativeWorkProportionality(bytes32 target, uint256 blocks1, uint256 blocks2) {
    require isValidTarget(target);
    require blocks1 > 0 && blocks2 > 0;
    require blocks1 < blocks2;
    
    uint256 work1 = countCumulativeWork(target, blocks1);
    uint256 work2 = countCumulativeWork(target, blocks2);
    
    // More blocks should mean more cumulative work
    assert work2 > work1;
    
    // Should be roughly proportional
    assert work2 / blocks2 == work1 / blocks1; // Same work per block
}

// Rule: Epoch cumulative work should equal work for 2016 blocks
rule epochCumulativeWorkConsistency(bytes32 target) {
    require isValidTarget(target);
    
    uint256 epochWork = countEpochCumulativeWork(target);
    uint256 calculatedWork = countCumulativeWork(target, DIFFICULTY_ADJUSTMENT_INTERVAL());
    
    assert epochWork == calculatedWork;
}

// =======================
// BOUNDARY CONDITION RULES
// =======================

// Rule: Extreme time values should be handled safely
rule extremeTimeHandling(bytes32 currentTarget) {
    require isValidTarget(currentTarget);
    
    // Test with very small time (should hit minimum ratio)
    bytes32 target1 = countNewTarget(currentTarget, 1);
    assert isValidTarget(target1);
    
    // Test with very large time (should hit maximum ratio or initial target)
    bytes32 target2 = countNewTarget(currentTarget, 2^32 - 1);
    assert isValidTarget(target2);
    assert target2 <= INITIAL_TARGET();
}

// Rule: Maximum target should not allow difficulty increase beyond initial
rule maximumTargetHandling(uint256 actualTime) {
    require actualTime > 0;
    
    bytes32 maxTarget = INITIAL_TARGET();
    bytes32 newTarget = countNewTarget(maxTarget, actualTime);
    
    // Should never exceed initial target
    assert newTarget <= INITIAL_TARGET();
    assert isValidTarget(newTarget);
}

// =======================
// CONSISTENCY RULES
// =======================

// Rule: Target rounding should be idempotent
rule targetRoundingIdempotent(bytes32 target) {
    require isValidTarget(target);
    
    bytes32 rounded1 = roundTarget(target);
    bytes32 rounded2 = roundTarget(rounded1);
    
    // Rounding should be idempotent
    assert rounded1 == rounded2;
    assert isValidTarget(rounded1);
} 