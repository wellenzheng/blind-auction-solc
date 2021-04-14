// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16 <0.9.0;

contract BlindAuction {
    address payable public beneficiary;
    uint256 public bidEndTime;
    uint256 public revealEndTime;
    uint256 public startPrice;
    uint256 public deposit;
    uint256 public depositRate;
    Product public product;
    bool public locked;
    bool public auctionEnded;
    bool public revealEnded;

    address public highestBidder;
    uint256 public highestBid;
    string public highestBidEncrypt;
    string public highestBidPubKey;

    string public bidEncryptA;
    string public bidEncryptB;
    address public bidComAddressA;
    address public bidComAddressB;
    uint256 public compareCounts;

    uint256 public bidsCount;
    mapping(address => Bid) bids;
    mapping(address => uint256) pendingReturns;

    event SummitComResult();
    event AuctionEnd();
    event RevealEnd(address winner, uint256 highestBid);

    struct Product {
        uint256 id;
        string name;
        string category;
        uint256 startPrice;
        string desc;
    }

    struct Bid {
        string blindBid;
        string publicKey;
        uint256 deposit;
    }

    modifier onlyBefore(uint256 _time) {
        require(block.timestamp < _time);
        _;
    }

    modifier onlyAfter(uint256 _time) {
        require(block.timestamp > _time);
        _;
    }

    modifier strEquals(string memory str1, string memory str2) {
        require(
            keccak256(abi.encodePacked(str1)) ==
                keccak256(abi.encodePacked(str2))
        );
        _;
    }

    constructor(
        uint256 _biddingTime,
        uint256 _revealTime,
        uint256 _id,
        string memory _name,
        string memory _category,
        uint256 _startPrice,
        string memory _desc
    ) {
        beneficiary = payable(msg.sender);
        bidEndTime = block.timestamp + _biddingTime;
        revealEndTime = bidEndTime + _revealTime;
        startPrice = _startPrice;
        depositRate = 20;
        deposit = (_startPrice * depositRate) / 100;
        product = Product({
            id: _id,
            name: _name,
            category: _category,
            startPrice: _startPrice,
            desc: _desc
        });
    }

    function bid(string memory _blindBid, string memory _publicKey)
        public
        payable
        onlyBefore(bidEndTime)
    {
        require(deposit == msg.value);
        bids[msg.sender] = Bid({
            blindBid: _blindBid,
            publicKey: _publicKey,
            deposit: msg.value
        });
    }

    function summitComNumbers(
        string memory _bidEncryptA,
        string memory _bidEncryptB
    ) public onlyAfter(bidEndTime) onlyBefore(revealEndTime) {
        require(!locked);
        locked = true;
        bidEncryptA = _bidEncryptA;
        bidEncryptB = _bidEncryptB;
        bidComAddressA = highestBidder;
        bidComAddressB = msg.sender;
        emit SummitComResult();
    }

    function summitComResult(address _highestBidder)
        public
        onlyAfter(bidEndTime)
        onlyBefore(revealEndTime)
    {
        require(msg.sender == highestBidder);
        require(locked);
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] = bids[highestBidder].deposit;
        }
        highestBidder = _highestBidder;
        highestBidEncrypt = bids[highestBidder].blindBid;
        highestBidPubKey = bids[highestBidder].publicKey;
        compareCounts++;
        locked = false;
    }

    function summitHighestBid(
        string memory _highestBidEncrypt,
        uint256 _highestBid
    )
        public
        onlyAfter(revealEndTime)
        strEquals(_highestBidEncrypt, highestBidEncrypt)
    {
        require(compareCounts == bidsCount);
        require(msg.sender == highestBidder);
        highestBid = _highestBid;
    }

    function withdraw() public onlyAfter(revealEndTime) {
        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }

    function auctionEnd()
        public
        onlyAfter(bidEndTime)
        onlyBefore(revealEndTime)
    {
        require(!auctionEnded);
        require(!revealEnded);
        emit AuctionEnd();
        auctionEnded = true;
    }

    function revealEnd() public onlyAfter(revealEndTime) {
        require(!revealEnded);
        emit RevealEnd(highestBidder, highestBid);
        revealEnded = true;
        beneficiary.transfer(highestBid);
    }

    function reveal(
        uint256 _value,
        bool _fake,
        bytes32 _secret
    ) public onlyAfter(bidEndTime) onlyBefore(revealEndTime) {
        uint256 refund;
        Bid storage bidToCheck = bids[msg.sender];
        if (
            keccak256(abi.encodePacked(bidToCheck.blindBid)) !=
            keccak256(abi.encodePacked(_value, _fake, _secret))
        ) {
            return;
        }
        refund += bidToCheck.deposit;
        if (!_fake && bidToCheck.deposit == deposit) {
            if (placeBid(msg.sender, _value)) {
                refund -= _value;
            }
        }
        bidToCheck.blindBid = "";
        payable(msg.sender).transfer(refund);
    }

    function placeBid(address bidder, uint256 value) internal returns (bool) {
        if (value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = bidder;
        highestBid = value;
        return true;
    }
}
