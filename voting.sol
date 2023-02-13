// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    address internal admin;

    constructor() {
        admin = msg.sender;
    }

    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    struct Proposal {
        string description;
        uint voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    mapping (address => Voter) voters;
    mapping (uint => uint) votedProposals;

    Proposal[] public proposals;
    Proposal[] internal winners;
    Proposal internal candidate;
    Proposal[] internal _tempWinners;

    WorkflowStatus public currentStatus;
    WorkflowStatus public previousStatus;
    WorkflowStatus public nextStatus;

    bool internal registration;
    bool internal ballot;

    uint internal w;
    uint public winningProposalID;

    modifier isRegistered() {
        require(voters[msg.sender].isRegistered==true, "Address Not Registered.");
        _;
    }

    modifier checkStatus() {
        require(registration!=ballot, "Operation outside event scope.");
        _;
    }

    function registerVoter(address voterAddress) public onlyOwner {
        voters[voterAddress].isRegistered = true;
        emit VoterRegistered(voterAddress);     
    }

    function startProposalReg() public onlyOwner {
        setCurrentStatus(WorkflowStatus.ProposalsRegistrationStarted);
        registration = true;
        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters, 
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    function registerProposal(uint proposalId, string calldata txt) external isRegistered checkStatus {
        Proposal memory _proposal = Proposal(txt, 0);
        proposals.push(_proposal);
        emit ProposalRegistered(proposalId);        
    }

    function endProposalReg() public onlyOwner {
        setCurrentStatus(WorkflowStatus.ProposalsRegistrationEnded);
        registration = false;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    function startBallot() public onlyOwner {
        setCurrentStatus(WorkflowStatus.VotingSessionStarted);
        ballot = true;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    function vote(address voterAddress, uint proposalId) external isRegistered checkStatus {
        voters[voterAddress].hasVoted = true;
        voters[voterAddress].votedProposalId = proposalId;
        votedProposals[proposalId] += 1;
        emit Voted(voterAddress, proposalId);
    }

    function endBallot() public onlyOwner {
        setCurrentStatus(WorkflowStatus.VotingSessionEnded);
        ballot = false;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    function findWinner() public onlyOwner {
        require(proposals.length != 0, "No votes to assign winner...");
        uint i = 0;
        while (i<proposals.length) {
            candidate = mostVotes(candidate, proposals[i]);
            if (keccak256(bytes(proposals[i].description)) == keccak256(bytes(candidate.description))) w=i;
            i++;
        }
        if (winners.length!=0) {
            candidate = startSuddenDeath();
        } else {
            winningProposalID = w;
        }
    }

    function mostVotes(Proposal memory _candidate, Proposal memory _proposal) public returns (Proposal memory) {
        Proposal memory output;
        if (_candidate.voteCount > _proposal.voteCount) {
            output = Proposal(_candidate.description, _candidate.voteCount);
        } else if (_candidate.voteCount < _proposal.voteCount) {
            if (winners.length != 0){
                uint i = 0;
                while (i < winners.length) {
                    winners.pop();
                    i++;
                }
            }
            output = Proposal(_proposal.description, _proposal.voteCount);
        } else {
            if (winners.length == 0) {
                if (keccak256(bytes(winners[winners.length-1].description)) != keccak256(bytes(_candidate.description))) {
                    winners.push(_candidate);
                    winners.push(_proposal);
                    output = Proposal(_proposal.description, _proposal.voteCount);
                } else {
                    output = Proposal(_candidate.description, _candidate.voteCount);
                }
            } else {
                if (keccak256(bytes(winners[winners.length-1].description)) != keccak256(bytes(_candidate.description))) {
                    winners.push(_proposal);
                    output = Proposal(_proposal.description, _proposal.voteCount);
                }
            }
        } 
        return output;
    }

    function startSuddenDeath() internal onlyOwner returns (Proposal memory) {
        Proposal memory output;
        if (winners.length == 2) {
            if (block.timestamp % 2 == 0) {
                output = Proposal(winners[0].description, winners[0].voteCount);
            } else {
                output = Proposal(winners[1].description, winners[1].voteCount);
            }
        } else {
            output = deathRun();
        }
        return output;
    }

    function deathRun() internal onlyOwner returns (Proposal memory) {
        Proposal memory _temp;
         _tempWinners = winners;
        while (1<_tempWinners.length) {
            if (block.timestamp % 2 == 0) {
                _temp = _tempWinners[_tempWinners.length-1];
            } else {
                _temp = _tempWinners[_tempWinners.length-2];
            }
            _tempWinners.pop();
            _tempWinners.pop();
            _tempWinners.push(_temp);
        }
        return _temp;
    }


    function setCurrentStatus(WorkflowStatus _status) internal {
        currentStatus = _status;
    }

    function setNextStatus(WorkflowStatus _status) internal {
        nextStatus = _status;
    }

    function setPreviousStatus(WorkflowStatus _status) internal {
        previousStatus = _status;
    }

    function getWinner() public view returns (Proposal memory) {
        if (winners.length != 0) return candidate;
        return proposals[w];
    }

    function getCurrentStatus() external view returns (WorkflowStatus) {
        return currentStatus;
    }

    function getNextStatus() external view returns (WorkflowStatus) {
        return nextStatus;
    }

    function getPreviousStatus() external view returns (WorkflowStatus){
        return previousStatus;
    }
}
