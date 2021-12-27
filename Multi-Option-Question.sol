pragma solidity ^0.8.4;

import "./libraries/NativeMetaTransaction/OwnableUpgradable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./libraries/NativeMetaTransaction/NativeMetaTransaction.sol";
import "./Factory.sol";

contract Factory is Initializable, UUPSUpgradeable, OwnableUpgradable, NativeMetaTransaction {
    struct QuestionEncodedData {
        bytes32 gameID;
        bytes32 questionID;
        bytes data;
    }

    mapping(bytes32 => address[]) public questionAddressArray;
    mapping(bytes32 => address) public questionAddressMap;
    mapping(bytes32 => mapping(address => bool)) public isGameClaimed;
    mapping(bytes32 => bool) public isGameTreasuryClaimed;
    mapping(bytes32 => address) public questionType;
    address public adminAddress;
    address public operatorAddress;
    address public whitelistAddress;

 event QuestionCreated(
        bytes32 indexed gameID,
        bytes32 indexed questionID,
        address indexed questionAddress,
        uint256 questionArrayLength
    );

        event SetAdmin(address indexed adminAddress);
    event SetOperator(address indexed operatorAddress);
    event SetWhitelist(address indexed whitelistAddress);
    event QuestionTypeAdded(bytes32 indexed id, address indexed questionAddress);

    function initialize(address _adminAddress, address _whitelistAddress, address _operatorAddress) external initializer {
        __Ownable_init();
        _initializeEIP712("Prediction-Market");
        require(_adminAddress != address(0), "Cannot be zero address");
        require(_operatorAddress != address(0), "Cannot be zero address");
          require(_whitelistAddress != address(0), "Cannot be zero address");
        adminAddress = _adminAddress;
        operatorAddress = _operatorAddress;
        whitelistAddress = _whitelistAddress;
    }

     modifier onlyOperator() {
        require(_msgSender() == operatorAddress, "operator: wut?");
        _;
    }

    modifier onlyAdmin() {
        require(_msgSender() == adminAddress, "admin: wut?");
        _;
    }

      function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setAdmin(address _adminAddress) external onlyAdmin {
        require(_adminAddress != address(0), "Cannot be zero address");
        adminAddress = _adminAddress;
        emit SetAdmin(adminAddress);
    }

    function setOperator(address _operatorAddress) external onlyAdmin {
        require(_operatorAddress != address(0), "Cannot be zero address");
        operatorAddress = _operatorAddress;
        emit SetOperator(operatorAddress);
    }

      function setwhitelist(address _whitelistAddress) external onlyAdmin {
        require(_whitelistAddress != address(0), "Cannot be zero address");
        whitelistAddress = _whitelistAddress;
        emit Setwhitelist(whitelistAddress);
    }

      function addQuestionType(bytes32 _id, address _questionAddress) external onlyAdmin {
        require(questionType[_id] == address(0), "Implementation Exists");
        questionType[_id] = _questionAddress;
        emit QuestionTypeAdded(_id, _questionAddress);
    }

    //Deploy questions
    function deployQuestions(bytes32 _id, QuestionEncodedData[] memory questionData) external onlyAdmin {
        uint256 len = questionData.length;
        address questionContract = questionType[_id];
        require(questionContract != address(0), "Strategy Doesnt Exist");
        for (uint256 i = 0; i < len; i++) {
            require(questionAddressMap[questionData[i].questionID] == address(0), "Question already deployed");
            address questionClone = ClonesUpgradeable.clone(questionContract);
            bytes memory payload = abi.encodeWithSelector(
                0x660b88ee,
                questionData[i].data,
                adminAddress,
                operatorAddress
            );
            (bool success, bytes memory returnData) = address(questionClone).call(payload);
            require(success && (returnData.length == 0 || abi.decode(returnData, (bool))), "Initialization Failed");
            questionAddressArray[questionData[i].gameID].push(questionClone);
            questionAddressMap[questionData[i].questionID] = questionClone;
            emit QuestionCreated(
                questionData[i].gameID,
                questionData[i].questionID,
                questionClone,
                questionData.length
            );
        }
    }


function placeTheBet(bytes32 questionID, bytes memory data) external {
        address whitelistAddress = _msgSender();
        address gameQuestion = questionAddressMap[questionID];
        require(gameQuestion != address(0), "Question Does not exist");
        bytes memory payload = abi.encodeWithSelector(0x3bcce78b, data, whitelistAddress);
        (bool success, bytes memory returnData) = address(gameQuestion).call(payload);
        require(success && (returnData.length == 0 || abi.decode(returnData, (bool))), "Bet Failed");
    }

    function claimBet(bytes32 questionID) external {
        address whitelistAddress = _msgSender();
        address gameQuestion = questionAddressMap[questionID];
        require(gameQuestion != address(0), "Question Does not exist");
        bytes memory payload = abi.encodeWithSelector(0x1e83409a, whitelistAddress);
        (bool success, bytes memory returnData) = address(gameQuestion).call(payload);
        require(success && (returnData.length == 0 || abi.decode(returnData, (bool))), "Claim Failed");
         isPrizeClaimed[prizepool][whitelistAddress] = true;
    }

    function claimGameBets(bytes32 gameID) external {
        address whitelistAddress = _msgSender();
        require(!isGameClaimed[gameID][whitelistAddress], "Game rewards already claimed by user");
        uint256 len = questionAddressArray[gameID].length;
        bytes memory payload = abi.encodeWithSelector(0x1e83409a, whitelistAddress);
        for (uint256 i = 0; i < len; i++) {
            address gameQuestion = questionAddressArray[gameID][i];
            require(gameQuestion != address(0), "Question Does not exist");
            (bool success, bytes memory returnData) = address(gameQuestion).call(payload);
            require(success && (returnData.length == 0 || abi.decode(returnData, (bool))), "ClaimGame Failed");
        }
         isPrizeClaimed[prizepool][whitelistAddress] = true;
        isGameClaimed[gameID][whitelistAddress] = true;
    }

     //Claim Game Treasury
    function claimGameTreasury(bytes32 gameID) external onlyAdmin {
        require(!isGameTreasuryClaimed[gameID], "Game's Treasury Has been claimed");
        bytes memory payload = abi.encodeWithSelector(0x003bdc74);
        uint256 len = questionAddressArray[gameID].length;
        for (uint256 i = 0; i < len; i++) {
            address gameQuestion = questionAddressArray[gameID][i];
            require(gameQuestion != address(0), "Question Does not exist");
            (bool success, bytes memory returnData) = address(gameQuestion).call(payload);
            require(success && (returnData.length == 0 || abi.decode(returnData, (bool))), "ClaimGameTreasury Failed");
        }
        isGameTreasuryClaimed[gameID] = true;
    }

    function getGameQuestions(bytes32 gameID) external view returns (address[] memory) {
        return questionAddressArray[gameID];
    }

    function getGameQuestionAddress(bytes32 questionID) external view returns (address questionAddress) {
        questionAddress = questionAddressMap[questionID];
    }
}

contract prizepool{
	int128 totalprizemoney ;
	int128 winningwhitelistuser ;
	
	function totalprizemoneySet(int64 x) public
	{
		totalprizemoney= x;
	}
	

	function winningwhitelistuserSet(int64 y) public
	{
		winningwhitelistuser = y;
	}
	

	function Divide() view public returns (int128)
	{   
        int128 answer = totalprizemoney / winningwhitelistuser ;
		return answer; 
        
	}

    function loop() public returns(uint[] memory){
    for(uint i=0; i<n; i++){
        prize.Divide(i);
        
     }
      return prize;
    }
}









