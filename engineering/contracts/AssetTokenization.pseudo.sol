// SPDX-License-Identifier: UNLICENSED
// Pseudocode contract for a permissioned consortium-chain tokenization baseline.
// This is intentionally implementation-neutral. Adapt types and access control
// to Fabric, FISCO BCOS, Quorum/IBFT, Besu, ChainMaker, or another permissioned stack.

pragma solidity-like ^0.8.0;

contract AssetTokenization {
    enum AssetStatus {
        None,
        Created,
        Issued,
        Frozen,
        Transferred,
        Redeemed,
        Burned
    }

    struct Asset {
        bytes32 assetId;
        string assetType;
        address issuer;
        address owner;
        uint256 amount;
        bytes32 metadataHash;
        AssetStatus status;
        bytes32 createdByTaskHash;
        bytes32 updatedByTaskHash;
        uint256 createdAt;
        uint256 updatedAt;
    }

    struct AgentAuthorization {
        bool active;
        bytes32[] roles;
        uint256 expiresAt;
    }

    mapping(bytes32 => Asset) private assets;
    mapping(address => bool) private institutions;
    mapping(address => AgentAuthorization) private agents;
    mapping(bytes32 => bool) private consumedActionHashes;

    address public governance;
    address public policyOracle;

    event InstitutionRegistered(address indexed institution);
    event InstitutionDisabled(address indexed institution);
    event AgentAuthorized(address indexed agent, bytes32[] roles, uint256 expiresAt);
    event AgentDisabled(address indexed agent);

    event AgentTaskLinked(bytes32 indexed agentTaskHash, bytes32 indexed assetId, bytes32 txRef);
    event AssetRegistered(bytes32 indexed assetId, address indexed issuer, bytes32 metadataHash);
    event AssetIssued(bytes32 indexed assetId, address indexed owner, uint256 amount);
    event AssetTransferred(bytes32 indexed assetId, address indexed from, address indexed to, uint256 amount);
    event AssetFrozen(bytes32 indexed assetId, address indexed operator, bytes32 reasonHash);
    event AssetUnfrozen(bytes32 indexed assetId, address indexed operator);
    event AssetRedeemed(bytes32 indexed assetId, address indexed owner, uint256 amount);
    event AssetBurned(bytes32 indexed assetId, address indexed operator);
    event FundShareTokenIssued(bytes32 indexed assetId, address indexed lp, bytes32 rightsMappingHash, bytes32 legalDocumentHash);
    event PortfolioEquityRWAIssued(bytes32 indexed assetId, bytes32 indexed fundId, bytes32 portfolioCompanyHash, bytes32 rightsMappingHash);
    event ComputeRevenueRecorded(bytes32 indexed assetId, address indexed beneficiary, uint256 computeUnits, uint256 revenueAmount, bytes32 oracleAttestationHash);

    modifier onlyGovernance() {
        require(msg.sender == governance, "ONLY_GOVERNANCE");
        _;
    }

    modifier onlyAuthorizedCaller(bytes32 requiredRole) {
        require(institutions[msg.sender] || _agentHasRole(msg.sender, requiredRole), "UNAUTHORIZED_CALLER");
        _;
    }

    modifier uniqueAction(bytes32 agentTaskHash, bytes32 actionHash) {
        require(agentTaskHash != bytes32(0), "EMPTY_TASK_HASH");
        require(actionHash != bytes32(0), "EMPTY_ACTION_HASH");
        bytes32 replayKey = keccak256(abi.encodePacked(agentTaskHash, actionHash));
        require(!consumedActionHashes[replayKey], "ACTION_ALREADY_CONSUMED");
        _;
        consumedActionHashes[replayKey] = true;
    }

    constructor(address initialGovernance, address initialPolicyOracle) {
        governance = initialGovernance;
        policyOracle = initialPolicyOracle;
        institutions[initialGovernance] = true;
    }

    function registerInstitution(address institution) external onlyGovernance {
        require(institution != address(0), "INVALID_INSTITUTION");
        institutions[institution] = true;
        emit InstitutionRegistered(institution);
    }

    function disableInstitution(address institution) external onlyGovernance {
        institutions[institution] = false;
        emit InstitutionDisabled(institution);
    }

    function authorizeAgent(
        address agent,
        bytes32[] calldata roles,
        uint256 expiresAt
    ) external onlyGovernance {
        require(agent != address(0), "INVALID_AGENT");
        require(expiresAt > block.timestamp, "INVALID_EXPIRY");
        agents[agent] = AgentAuthorization({
            active: true,
            roles: roles,
            expiresAt: expiresAt
        });
        emit AgentAuthorized(agent, roles, expiresAt);
    }

    function disableAgent(address agent) external onlyGovernance {
        agents[agent].active = false;
        emit AgentDisabled(agent);
    }

    function registerAsset(
        bytes32 agentTaskHash,
        bytes32 assetId,
        string calldata assetType,
        bytes32 metadataHash
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("registerAsset", assetId)))
        onlyAuthorizedCaller("ASSET_REGISTER")
    {
        require(assetId != bytes32(0), "EMPTY_ASSET_ID");
        require(assets[assetId].status == AssetStatus.None, "ASSET_EXISTS");
        require(metadataHash != bytes32(0), "EMPTY_METADATA_HASH");
        _requirePolicyApproved(agentTaskHash, "registerAsset");

        assets[assetId] = Asset({
            assetId: assetId,
            assetType: assetType,
            issuer: msg.sender,
            owner: msg.sender,
            amount: 0,
            metadataHash: metadataHash,
            status: AssetStatus.Created,
            createdByTaskHash: agentTaskHash,
            updatedByTaskHash: agentTaskHash,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit AssetRegistered(assetId, msg.sender, metadataHash);
    }

    function issueAsset(
        bytes32 agentTaskHash,
        bytes32 assetId,
        address owner,
        uint256 amount
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("issueAsset", assetId, owner, amount)))
        onlyAuthorizedCaller("ASSET_ISSUE")
    {
        Asset storage asset = assets[assetId];
        require(asset.status == AssetStatus.Created, "INVALID_STATUS");
        require(msg.sender == asset.issuer || institutions[msg.sender], "NOT_ISSUER_OR_INSTITUTION");
        require(owner != address(0), "INVALID_OWNER");
        require(amount > 0, "INVALID_AMOUNT");
        _requirePolicyApproved(agentTaskHash, "issueAsset");

        asset.owner = owner;
        asset.amount = amount;
        asset.status = AssetStatus.Issued;
        asset.updatedByTaskHash = agentTaskHash;
        asset.updatedAt = block.timestamp;

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit AssetIssued(assetId, owner, amount);
    }

    function transferAsset(
        bytes32 agentTaskHash,
        bytes32 assetId,
        address from,
        address to,
        uint256 amount
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("transferAsset", assetId, from, to, amount)))
        onlyAuthorizedCaller("ASSET_TRANSFER")
    {
        Asset storage asset = assets[assetId];
        require(asset.status == AssetStatus.Issued || asset.status == AssetStatus.Transferred, "NOT_TRANSFERABLE");
        require(asset.owner == from, "OWNER_MISMATCH");
        require(to != address(0), "INVALID_RECIPIENT");
        require(amount > 0 && amount <= asset.amount, "INVALID_AMOUNT");
        _requirePolicyApproved(agentTaskHash, "transferAsset");

        // Baseline model treats each asset record as a single-owner balance.
        // Split/partial-transfer variants should mint a child asset or update a balance ledger.
        require(amount == asset.amount, "PARTIAL_TRANSFER_REQUIRES_SPLIT_MODEL");

        asset.owner = to;
        asset.status = AssetStatus.Transferred;
        asset.updatedByTaskHash = agentTaskHash;
        asset.updatedAt = block.timestamp;

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit AssetTransferred(assetId, from, to, amount);
    }

    function freezeAsset(
        bytes32 agentTaskHash,
        bytes32 assetId,
        bytes32 reasonHash
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("freezeAsset", assetId, reasonHash)))
        onlyAuthorizedCaller("ASSET_FREEZE")
    {
        Asset storage asset = assets[assetId];
        require(asset.status == AssetStatus.Issued || asset.status == AssetStatus.Transferred, "NOT_FREEZABLE");
        require(reasonHash != bytes32(0), "EMPTY_REASON_HASH");
        _requirePolicyApproved(agentTaskHash, "freezeAsset");

        asset.status = AssetStatus.Frozen;
        asset.updatedByTaskHash = agentTaskHash;
        asset.updatedAt = block.timestamp;

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit AssetFrozen(assetId, msg.sender, reasonHash);
    }

    function unfreezeAsset(
        bytes32 agentTaskHash,
        bytes32 assetId
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("unfreezeAsset", assetId)))
        onlyAuthorizedCaller("ASSET_UNFREEZE")
    {
        Asset storage asset = assets[assetId];
        require(asset.status == AssetStatus.Frozen, "NOT_FROZEN");
        _requirePolicyApproved(agentTaskHash, "unfreezeAsset");

        asset.status = AssetStatus.Transferred;
        asset.updatedByTaskHash = agentTaskHash;
        asset.updatedAt = block.timestamp;

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit AssetUnfrozen(assetId, msg.sender);
    }

    function redeemAsset(
        bytes32 agentTaskHash,
        bytes32 assetId,
        uint256 amount
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("redeemAsset", assetId, amount)))
        onlyAuthorizedCaller("ASSET_REDEEM")
    {
        Asset storage asset = assets[assetId];
        require(asset.status == AssetStatus.Issued || asset.status == AssetStatus.Transferred, "NOT_REDEEMABLE");
        require(amount > 0 && amount <= asset.amount, "INVALID_AMOUNT");
        _requirePolicyApproved(agentTaskHash, "redeemAsset");

        asset.amount = asset.amount - amount;
        asset.status = asset.amount == 0 ? AssetStatus.Redeemed : asset.status;
        asset.updatedByTaskHash = agentTaskHash;
        asset.updatedAt = block.timestamp;

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit AssetRedeemed(assetId, asset.owner, amount);
    }

    function burnAsset(
        bytes32 agentTaskHash,
        bytes32 assetId
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("burnAsset", assetId)))
        onlyAuthorizedCaller("ASSET_BURN")
    {
        Asset storage asset = assets[assetId];
        require(asset.status != AssetStatus.None, "ASSET_NOT_FOUND");
        require(asset.status != AssetStatus.Burned, "ALREADY_BURNED");
        _requirePolicyApproved(agentTaskHash, "burnAsset");

        asset.amount = 0;
        asset.status = AssetStatus.Burned;
        asset.updatedByTaskHash = agentTaskHash;
        asset.updatedAt = block.timestamp;

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit AssetBurned(assetId, msg.sender);
    }

    function issueFundShareToken(
        bytes32 agentTaskHash,
        bytes32 assetId,
        address lp,
        uint256 shareUnits,
        bytes32 rightsMappingHash,
        bytes32 legalDocumentHash
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("issueFundShareToken", assetId, lp, shareUnits)))
        onlyAuthorizedCaller("FUND_SHARE_ISSUE")
    {
        require(assets[assetId].status == AssetStatus.None, "ASSET_EXISTS");
        require(lp != address(0), "INVALID_LP");
        require(shareUnits > 0, "INVALID_UNITS");
        require(rightsMappingHash != bytes32(0), "EMPTY_RIGHTS_MAPPING");
        require(legalDocumentHash != bytes32(0), "EMPTY_LEGAL_DOC");
        _requirePolicyApproved(agentTaskHash, "issueFundShareToken");

        assets[assetId] = Asset({
            assetId: assetId,
            assetType: "FundShareToken",
            issuer: msg.sender,
            owner: lp,
            amount: shareUnits,
            metadataHash: rightsMappingHash,
            status: AssetStatus.Issued,
            createdByTaskHash: agentTaskHash,
            updatedByTaskHash: agentTaskHash,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit FundShareTokenIssued(assetId, lp, rightsMappingHash, legalDocumentHash);
    }

    function issuePortfolioEquityRWA(
        bytes32 agentTaskHash,
        bytes32 assetId,
        bytes32 fundId,
        bytes32 portfolioCompanyHash,
        uint256 equityUnits,
        bytes32 rightsMappingHash,
        bytes32 legalDocumentHash
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("issuePortfolioEquityRWA", assetId, fundId, equityUnits)))
        onlyAuthorizedCaller("PORTFOLIO_EQUITY_ISSUE")
    {
        require(assets[assetId].status == AssetStatus.None, "ASSET_EXISTS");
        require(fundId != bytes32(0), "EMPTY_FUND_ID");
        require(equityUnits > 0, "INVALID_UNITS");
        require(rightsMappingHash != bytes32(0), "EMPTY_RIGHTS_MAPPING");
        require(legalDocumentHash != bytes32(0), "EMPTY_LEGAL_DOC");
        _requirePolicyApproved(agentTaskHash, "issuePortfolioEquityRWA");

        assets[assetId] = Asset({
            assetId: assetId,
            assetType: "PortfolioEquityRWA",
            issuer: msg.sender,
            owner: msg.sender,
            amount: equityUnits,
            metadataHash: rightsMappingHash,
            status: AssetStatus.Issued,
            createdByTaskHash: agentTaskHash,
            updatedByTaskHash: agentTaskHash,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit PortfolioEquityRWAIssued(assetId, fundId, portfolioCompanyHash, rightsMappingHash);
    }

    function recordComputeRevenue(
        bytes32 agentTaskHash,
        bytes32 assetId,
        address beneficiary,
        uint256 computeUnits,
        uint256 revenueAmount,
        bytes32 rightsMappingHash,
        bytes32 legalDocumentHash,
        bytes32 oracleAttestationHash
    )
        external
        uniqueAction(agentTaskHash, keccak256(abi.encodePacked("recordComputeRevenue", assetId, beneficiary, oracleAttestationHash)))
        onlyAuthorizedCaller("COMPUTE_REVENUE_RECORD")
    {
        require(beneficiary != address(0), "INVALID_BENEFICIARY");
        require(computeUnits > 0, "INVALID_COMPUTE_UNITS");
        require(revenueAmount > 0, "INVALID_REVENUE");
        require(rightsMappingHash != bytes32(0), "EMPTY_RIGHTS_MAPPING");
        require(legalDocumentHash != bytes32(0), "EMPTY_LEGAL_DOC");
        require(oracleAttestationHash != bytes32(0), "EMPTY_ORACLE_ATTESTATION");
        _requirePolicyApproved(agentTaskHash, "recordComputeRevenue");

        Asset storage asset = assets[assetId];
        if (asset.status == AssetStatus.None) {
            assets[assetId] = Asset({
                assetId: assetId,
                assetType: "ComputePowerToken",
                issuer: msg.sender,
                owner: beneficiary,
                amount: computeUnits,
                metadataHash: rightsMappingHash,
                status: AssetStatus.Issued,
                createdByTaskHash: agentTaskHash,
                updatedByTaskHash: agentTaskHash,
                createdAt: block.timestamp,
                updatedAt: block.timestamp
            });
        } else {
            require(asset.status == AssetStatus.Issued || asset.status == AssetStatus.Transferred, "INVALID_STATUS");
            asset.owner = beneficiary;
            asset.amount = computeUnits;
            asset.metadataHash = rightsMappingHash;
            asset.updatedByTaskHash = agentTaskHash;
            asset.updatedAt = block.timestamp;
        }

        emit AgentTaskLinked(agentTaskHash, assetId, _txRef());
        emit ComputeRevenueRecorded(assetId, beneficiary, computeUnits, revenueAmount, oracleAttestationHash);
    }

    function queryAsset(bytes32 assetId) external view returns (Asset memory) {
        require(assets[assetId].status != AssetStatus.None, "ASSET_NOT_FOUND");
        return assets[assetId];
    }

    function _agentHasRole(address agent, bytes32 requiredRole) internal view returns (bool) {
        AgentAuthorization memory auth = agents[agent];
        if (!auth.active || auth.expiresAt <= block.timestamp) {
            return false;
        }
        for (uint256 i = 0; i < auth.roles.length; i++) {
            if (auth.roles[i] == requiredRole) {
                return true;
            }
        }
        return false;
    }

    function _requirePolicyApproved(bytes32 agentTaskHash, string memory action) internal view {
        // Pseudocode: call permissioned-chain policy oracle or precompile.
        // The oracle verifies AgentTask, policy snapshot, authorization scope,
        // risk level, and schema-normalized payload hash before the transaction.
        require(
            PolicyOracle(policyOracle).isApproved(agentTaskHash, action, msg.sender),
            "POLICY_REJECTED"
        );
    }

    function _txRef() internal view returns (bytes32) {
        // Pseudocode placeholder. Actual permissioned stacks expose transaction
        // hash differently; indexers can also derive tx hash off-chain.
        return keccak256(abi.encodePacked(block.number, msg.sender, gasleft()));
    }
}

interface PolicyOracle {
    function isApproved(bytes32 agentTaskHash, string calldata action, address caller)
        external
        view
        returns (bool);
}
