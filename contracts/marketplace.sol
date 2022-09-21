// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;


import "./token/Token.sol";

contract marketplace {

    /* -------------------------------------- OTHER CONTRACT IMPORTATION -------------------------------------- */


    /* We first of all initialize the SocialToken contract's address in this contract
    since we will need to do payments in the Universe network.*/
    Token private token;
    address private tokenaddress = 0x8D5a5965338AaE0FbC02B16D1720c29f92CD7c94;
                                                                                                                                         
                                                        
    // ------------------------------------------------------------CONSTRUCTOR------------------------------------------------------------


    // In constructor we initialize the contract state and the current operation to the default values.
    constructor() {
        last = 0;
        token = Token(tokenaddress);
    }

    // ------------------------------------------------------------STRUCTS------------------------------------------------------------



    // First struct. The general one. Records all data about the program that will be computed.
    struct ProgData {
        uint n_players;     // The number of players in the SM network
        string CA;          // The CA certificate, for players to sign their CRTs with it
        uint reputation;
        uint prime;         // The prime we will use for the operations
        uint subscribed_players;
        uint payment;
        uint tokensPerItem;
        uint MODL;
        uint current_data;
        uint ready_players;
        uint finished_players;
        uint succeeded;
        uint scientist_vote;
        uint aborted;
        mapping (address => uint) elected;
        mapping (uint => PlayerData) Players;       // This mapping will connect an integer (0-n_players) to each player's data: IP, CRT and CN
        FilesLoc Files;     // In Files we record the locations (hashes) of the program files on IPFS.
        StateType ContractState;                    // Here we update the state of the contract for each thrown program.
    }

    // Second struct. Inside ProgData. We record the data of each player.
    struct PlayerData {
        address account;    // We record the account for the future rewards that will be given to the players
        string IP;          // The IP, CRT and CN of each player need to be recorded for the Setup of SM to be able to prove those CRTs
        string CRT;         // and write them on NetworkData.txt
        string CN;
        uint data_length;
        uint reputation;
    }

    // Third struct. Inside ProgData too. We record the locations of the files needed to run the mpc program in IPFS.
    struct FilesLoc {
        string BC;          // Hash of the folder containing the .bc and .sch files
        string SCH;
        string PREP;        // A program to preprocess the Excel table where the private data is. This program outputs a txt
                            // where the data of the Excel file will be readable for the BC
        string INFO;        // A file where some information is given about the program that will be computed and, of course, about
                            // the kind of data that will be needed (type, units, how to write the Excel...)
    }

    // ------------------------------------------------------------EVENTS------------------------------------------------------------

    // First event. This will log in the blockchain that an operation has been thrown. This way, all players will be able to know that
    // an operation is about to happen and that it's time to sign up to it.
    event newRequest(
        uint i,
        string info
    );

    event updatedRequest(
        uint i,
        string info
    );

    event operationThrown(
        uint i
    );

    event operation_finished(
        uint i
    );
    
    // Second event. This will log in the blockchain that the subscription time has ended (since the required players have signed up).
    // This event will tell the scientist if it's time to start the SM part.
    event playersFilled(
        uint i
    );

    // This event tells players that everyone has done the first Setup in SM. This way, they know that they can run the program securely.
    event network_ready(
        uint i
    );

    // -------------------------------------------------------OTHER VARIABLES-------------------------------------------------------

    // This mapping keeps in its keys all the ProgData structs and their information. 
    mapping (uint => ProgData) Prog;
    // This mappings record the reputations of players in the network.
    mapping (address => uint) registered;
    mapping (address => uint) reputations;

    uint public last;                    // The last item that has a struct in Prog.

    // There will be 3 states in this contract. The contract will give access to functions depending on its current state.
    enum StateType {ThrowOperation, SubscribingTime, OperationPending, OperationThrown, NetworkReady, Finished}      
    

    // ------------------------------------------------------- CALLDATA FUNCTIONS -------------------------------------------------------

    // The following function will return the actual contract state of a program for a user who wants to know.
    function return_state(uint i) external view returns (StateType, string memory, string memory, uint) {
        ProgData storage NewProg = Prog[i];
        string memory text1;
        string memory text2;
        uint number;
        if (NewProg.ContractState == StateType.SubscribingTime) {
            text1 = "We are at subscribing time";
            text2 = "Subscribed players:";
            number = NewProg.subscribed_players;
        }
        else if (NewProg.ContractState == StateType.OperationPending) {
            text1 = "We are waiting for the data scientist to throw the operation";
            text2 = "Subscribed players:";
            number = NewProg.subscribed_players;
        }
        else if (NewProg.ContractState == StateType.OperationThrown) {
            text1 = "We are waiting for all players to tell they are ready.";
            text2 = "Ready players at this moment";
            number = NewProg.ready_players;
        }
        else if (NewProg.ContractState == StateType.NetworkReady) {
            text1 = "The network is ready to start the SCALE-MAMBA computations.";
            text2 = "";
            number = 0;
        }
        return (NewProg.ContractState, text1, text2, number);
    }
    // This function returns Player[n]'s data (the IP, CRT and CN, in that order). This function cannot be called until all players 
    // required are subscribed, and only addresses who singed up to the operation can call it.
    function return_PlayerData(uint n, uint i) external view returns (uint, string memory, string memory, string memory, uint) {
        ProgData storage NewProg = Prog[i];
        require (NewProg.ContractState == StateType.OperationThrown, "You cannot execute this function at this moment.");
        require(NewProg.elected[msg.sender] == 1, "You are not allowed to obtain this information.");
        require(NewProg.elected[NewProg.Players[n].account] != 0, "This player is not elected, you cannot obtain the information.");
        uint my_n = 0;
        if (msg.sender == NewProg.Players[n].account) {
            my_n = 1;
        }
        return (n, NewProg.Players[n].IP, NewProg.Players[n].CRT, NewProg.Players[n].CN, my_n);
    }
    
    function return_subscribed_n(uint i) external view returns (uint) {
        ProgData storage NewProg = Prog[i];
        require(NewProg.ContractState == StateType.OperationPending, "You cannot execute this function at this moment.");
        require(msg.sender == NewProg.Players[0].account, "You are not allowed to obtain this information.");
        return NewProg.subscribed_players;
    }

    function return_PlayerData_private(uint n, uint i) external view returns (address, uint) {
        ProgData storage NewProg = Prog[i];
        require(msg.sender == NewProg.Players[0].account, "You cannot call this function.");
        require (NewProg.ContractState == StateType.OperationPending, "You cannot execute this function at this moment.");
        return (NewProg.Players[n].account, NewProg.Players[n].data_length);
    }

    function _elected(uint i) external view returns (uint) {
        ProgData storage NewProg = Prog[i];
        require(NewProg.ContractState == StateType.OperationThrown, "You cannot execute this function at this moment.");
        return NewProg.elected[msg.sender];
    }

    // This function returns the prime number that will be used in the program. Again, it can only be accesed when all players are 
    // signed up and they are the only ones that have access to it.
    function return_prime(uint i) external view returns (uint) {
        ProgData storage NewProg = Prog[i];
        require (NewProg.ContractState == StateType.OperationThrown || NewProg.ContractState == StateType.Finished, "You cannot execute this function at this moment.");
        require(NewProg.elected[msg.sender] == 1, "You are not allowed to obtain this information.");
        return NewProg.prime;
    }

    // This function returns the required number of players. This function is needed to perform the Setup process properly. However,
    // it could be of interest to know the required number of players whenever a player wants (it's not relevant data).
    function return_n_players(uint i) external view returns (uint) {
        ProgData storage NewProg = Prog[i];
        require(NewProg.ContractState == StateType.OperationThrown, "You cannot obtain this information at this moment.");
        require(NewProg.elected[msg.sender] == 1, "You are not allowed to obtain this information.");
        return NewProg.n_players;
    }

    // This function returns the location of the documentation file about the program. We require, evidently, the program to be thrown,
    // but this function can be called whenever a user wants. This is because this file will tell a player what kind of data is needed
    // for this program, and how must it be writen in the Excel for the BC to be readable.
    function return_info(uint i) external view returns (string memory) {
        ProgData storage NewProg = Prog[i];
        require (NewProg.ContractState != StateType.ThrowOperation, "The file you are searching for is not uploaded yet. If you want, you can throw an operation to compute.");
        return NewProg.Files.INFO;
    }

    // This function returns the locations of the program files needed to run the Player. It cannot be called until all players are subscribed.
    function return_locs(uint i) external view returns (string memory, string memory, string memory) {
        ProgData storage NewProg = Prog[i];
        require (NewProg.ContractState == StateType.OperationThrown, "You cannot obtain this information yet.");
        require(NewProg.elected[msg.sender] == 1, "You are not allowed to obtain this information.");
        return (NewProg.Files.BC, NewProg.Files.SCH, NewProg.Files.PREP);
    }

    // This function returns the CA certificate. Again, this function can be called whenever a user wants, since (I think) it could be
    // needed before the Setup process.
    function return_CA(uint i) external view returns (string memory) {
        ProgData storage NewProg = Prog[i];
        require(NewProg.ContractState == StateType.SubscribingTime || NewProg.ContractState == StateType.OperationThrown, "You cannot obtain this information at this moment.");
        return NewProg.CA;
    }

    // This function outputs the upper and lower bounds of payments for participating in the SMPC of the program.
    function return_payment(uint i) external view returns (uint, uint) {
        ProgData storage NewProg = Prog[i];
        return (NewProg.payment, NewProg.MODL);
    }

    // This function returns the reputation of a user.
    function return_reputation() external view returns (uint) {
        return reputations[msg.sender];
    }

    // This function returns the required reputation of a request.
    function return_required_reputation(uint i) external view returns (uint) {
        ProgData storage NewProg = Prog[i];
        return NewProg.reputation;
    }

    // This function returns the required reputation of a request.
    function return_MODL(uint i) external view returns (uint) {
        ProgData storage NewProg = Prog[i];
        return NewProg.MODL;
    }

    function return_registered() external view returns (uint) {
        return registered[msg.sender];
    }

    //This function returns the amount of tokens a user has.
    function balance() external view returns (uint) {
        return token.balanceOf(msg.sender);
    }


    // -------------------------------------------------------AUXILIARY FUNCTIONS-------------------------------------------------------
    

    // This function returns a 0 if an account has already subscribed to the operation, and a 1 if it does not.
    function account_repeated (uint j) public view returns (uint) {
        ProgData storage NewProg = Prog[j];
        uint result = 1;
        for (uint i = 0; i < NewProg.subscribed_players; i++) {
            if (NewProg.Players[i].account == msg.sender) {
                result = 0;
                break;
            }
        }
        return result;
    }

    function withdraw(uint amount) external payable {
        token.transfer(msg.sender, amount);
    }

    // ------------------------------------------------------- MAIN FUNCTIONS -------------------------------------------------------


    // The following function updates the number of players that have picked up the SM networking information so far. When the number
    // of players reaches the required number of players, an event is emitted, for the leader to know that the operation can be run.
    function Im_ready(uint i) external {
        ProgData storage NewProg = Prog[i];
        require(NewProg.ContractState == StateType.OperationThrown, "The contract cannot proccess your claim in its current state.");
        require(NewProg.elected[msg.sender] == 1, "You are not allowed to tell you're ready.");
        NewProg.elected[msg.sender] = 2;
        NewProg.ready_players += 1;
        if (NewProg.ready_players == NewProg.n_players) {
            emit network_ready(i);
            NewProg.ContractState = StateType.NetworkReady;
        }
    }

    function finished(uint i, uint success) external {
        ProgData storage NewProg = Prog[i];
        require(NewProg.ContractState == StateType.NetworkReady, "The contract cannot proccess your claim in its current state.");
        require(NewProg.elected[msg.sender] == 2, "You are not allowed to tell you've finished.");
        if (msg.sender == NewProg.Players[0].account) {
            NewProg.scientist_vote = success;
        }
        NewProg.elected[msg.sender] = 3;
        NewProg.finished_players += 1;
        if (success == 0) {
            NewProg.aborted += 1;
        } else {
            NewProg.succeeded += 1;
        }
        if (NewProg.finished_players == NewProg.n_players) {
            emit operation_finished(i);
            if (NewProg.succeeded > NewProg.aborted) {
                pay_to_players(i);
            } else if (NewProg.succeeded == NewProg.aborted) {
                if (NewProg.scientist_vote == 1) {
                    pay_to_players(i);
                }
            }
            NewProg.ContractState = StateType.Finished;
        }
    }

    // All players, when registering in the marketplace, start with an initial reputation of 50 points. This reputation may
    // increase or decrease depending on their success when participating in SMPC requests.
    function register() external {
        require(registered[msg.sender] == 0, "You already registered in the marketplace.");
        registered[msg.sender] = 1;
        reputations[msg.sender] = 50;
    }

    // The signing up function is responsible for taking all the necessary information about the players that will form the SCALE-MAMBA network.
    // Inside it, we update the ProgData struct with all the new information about the player. When we reach the required number of players,
    // the players_filled event is logged into the blockchain, telling the leader that it is time to start the operation.
    function signup(uint my_data_length, string calldata myIP, string calldata myCRT, string calldata myCN, uint i, uint _reputation) external {
        require(reputations[msg.sender] >= _reputation, "You gambled more reputation than the one you have.");
        ProgData storage NewProg = Prog[i];
        require (NewProg.ContractState == StateType.SubscribingTime, "The contract cannot proccess your claim in its current state.");
        require (account_repeated(i) == 1, "You already have signed up for this operation.");
        require (_reputation >= NewProg.reputation, "Your reputation is not enough to participate in this SMPC.");
        require (my_data_length < NewProg.MODL, "Your data length must be less than the MODL.");
        reputations[msg.sender] -= _reputation;
        NewProg.Players[NewProg.subscribed_players] = PlayerData(
            {
                account: msg.sender,
                IP: myIP,
                CRT: myCRT,
                CN: myCN,
                data_length: my_data_length,
                reputation: _reputation
            }
        );
        NewProg.subscribed_players += 1;
        NewProg.current_data += my_data_length;
        if (NewProg.current_data >= NewProg.MODL) {
            NewProg.ContractState = StateType.OperationPending;
            emit playersFilled(i);
        }
    }
    
    function update_request(uint i, string[4] memory str_items, uint my_data_length, uint _MODL, uint min_reputation, uint tokens) external {
        // str_items = [CA, IP, CRT, CN]
        require(reputations[msg.sender] >= min_reputation, "You required more reputation than the one you have.");
        require(token.balanceOf(msg.sender) >= tokens, "You promised more tokens than the ones you have.");
        require (i <= last, "There is no previous operation to update at this index.");
        ProgData storage NewProg = Prog[i];
        require (NewProg.ContractState == StateType.Finished, "This program has not finished yet. You cannot update it.");
        for (uint j = 0; j < NewProg.subscribed_players; j++) {
            NewProg.elected[NewProg.Players[j].account] = 0;
        }
        NewProg.CA = str_items[0];
        NewProg.reputation = min_reputation;
        reputations[msg.sender] -= min_reputation;
        NewProg.ContractState = StateType.SubscribingTime;
        NewProg.ready_players = 0;
        NewProg.finished_players = 0;
        NewProg.aborted = 0;
        NewProg.succeeded = 0;
        NewProg.scientist_vote = 0;
        NewProg.subscribed_players = 1;
        NewProg.MODL = _MODL;
        NewProg.payment = tokens;
        NewProg.current_data = my_data_length;
        NewProg.Players[0] = PlayerData(
            {
                account: msg.sender,
                IP: str_items[1],
                CRT: str_items[2],
                CN: str_items[3],
                data_length: my_data_length,
                reputation: min_reputation
            }
        );
        // Before calling this function we need to call the approve(tokenaddress, amount) from Token.sol
        token.transferFrom(msg.sender, address(this), tokens);
        emit updatedRequest(i, NewProg.Files.INFO);
    }

    // This function is the one that is called when throwing an operation. It updates the struct of the contract and tells the other
    // users that a new operation is thrown.
    function new_request(string[6] memory str_items, uint my_data_length, uint _MODL, uint min_reputation, uint tokens) external {
        // str_items = [CA, IP, CRT, CN, PREPROCESSING, INFORMATION]
        require(reputations[msg.sender] >= min_reputation, "You required more reputation than the one you have.");
        require(token.balanceOf(msg.sender) >= tokens, "You promised more tokens than the ones you have.");
        last = last + 1;
        ProgData storage NewProg = Prog[last];
        NewProg.CA = str_items[0];
        NewProg.reputation = min_reputation;
        reputations[msg.sender] -= min_reputation;
        NewProg.ContractState = StateType.SubscribingTime;
        NewProg.subscribed_players = 1;
        NewProg.MODL = _MODL;
        NewProg.payment = tokens;
        NewProg.current_data = my_data_length;
        NewProg.Players[0] = PlayerData(
            {
                account: msg.sender,
                IP: str_items[1],
                CRT: str_items[2],
                CN: str_items[3],
                data_length: my_data_length,
                reputation: min_reputation
            }
        );
        NewProg.Files.PREP = str_items[4];
        NewProg.Files.INFO = str_items[5];
        // Before calling this function we need to call the approve(tokenaddress, amount) from Token.sol
        token.transferFrom(msg.sender, address(this), tokens);
        emit newRequest(last, str_items[5]);
    }

    function throw_operation(uint prime, address[] calldata elected_players, string calldata BC_hash, string calldata SCH_hash, uint i, uint actual_payment) external {
        ProgData storage NewProg = Prog[i];
        require(NewProg.ContractState == StateType.OperationPending, "You cannot call this function at this moment.");
        require(msg.sender == NewProg.Players[0].account, "You are not who made the request for this operation.");
        NewProg.prime = prime;
        NewProg.tokensPerItem = actual_payment;
        NewProg.n_players = elected_players.length;
        for (uint j = 0; j < NewProg.n_players; j++) {
            NewProg.elected[elected_players[j]] = 1;
        }
        NewProg.elected[msg.sender] = 1;
        NewProg.n_players += 1;
        NewProg.Files.BC = BC_hash;
        NewProg.Files.SCH = SCH_hash;
        NewProg.ContractState = StateType.OperationThrown;
        emit operationThrown(i);
    }

    function pay_to_players(uint i) public payable {
        ProgData storage NewProg = Prog[i];
        uint j;
        reputations[NewProg.Players[0].account] += 2 * NewProg.reputation;
        for (j = 1; j < NewProg.n_players; j++) {
            if (NewProg.elected[NewProg.Players[j].account] != 0) {
                reputations[NewProg.Players[j].account] += 2 * NewProg.Players[j].reputation;
                uint amount = NewProg.tokensPerItem * NewProg.Players[j].data_length;
                token.transfer(NewProg.Players[j].account, amount);
            }
        }
    }
}