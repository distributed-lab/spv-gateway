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
    function bitsToTargetReference(bytes4 bits_) external returns (bytes32) envfree;
    function targetToBits(bytes32 target_) external returns (bytes4) envfree;
    function targetToBitsReference(bytes32 target_) external returns (bytes4) envfree;
    function roundTarget(bytes32 currentTarget_) external returns (bytes32) envfree;
    function isValidTarget(bytes32 target_) external returns (bool) envfree;
    function isValidBits(bytes4 bits_) external returns (bool) envfree;
}

// Constants should have correct Bitcoin values
invariant constantsMatchBitcoinSpec()
    EXPECTED_TARGET_BLOCKS_TIME() == 1209600 && // 2 weeks in seconds
    DIFFICULTY_ADJUSTMENT_INTERVAL() == 2016 && // 2016 blocks per epoch
    TARGET_FIXED_POINT_FACTOR() == 10^18 && // Fixed point precision
    MAX_TARGET_FACTOR() == 4 && // Maximum 4x target change
    MAX_TARGET_RATIO() == TARGET_FIXED_POINT_FACTOR() * MAX_TARGET_FACTOR() &&
    MIN_TARGET_RATIO() == TARGET_FIXED_POINT_FACTOR() / MAX_TARGET_FACTOR();

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

// Rule: Verify that the Solidity bitsToTarget implementation matches the Bitcoin specification
rule bitsToTargetMatchesSpecification(uint32 bitsValue) {    
    bytes4 bits = to_bytes4(bitsValue);
    
    bytes32 expectedTarget = bitsToTargetReference(bits);
    bytes32 actualTarget = bitsToTarget(bits);

    require(assert_uint256(expectedTarget) <= assert_uint256(INITIAL_TARGET()), "Target is never greater than 32 bytes");
    
    assert expectedTarget == actualTarget, 
        "bitsToTarget implementation does not match Bitcoin specification";
}

// Rule: Verify that the Solidity targetToBits implementation matches the Bitcoin specification
rule targetToBitsMatchesSpecification(bytes32 targetValue) {    
    require(assert_uint256(targetValue) <= assert_uint256(INITIAL_TARGET()), "Target is never greater than 32 bytes");
    
    bytes4 expectedBits = targetToBitsReference(targetValue);
    bytes4 actualBits = targetToBits(targetValue);
    
    assert expectedBits == actualBits, 
        "targetToBits implementation does not match Bitcoin specification";
}
