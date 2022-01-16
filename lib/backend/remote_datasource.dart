import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:e_vote/backend/errors.dart';
import 'package:e_vote/models/candidate_model.dart';
import 'package:e_vote/models/voter_model.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';


class ElectionDataSource {

  String url =
      "https://rinkeby.infura.io/v3/62452ae1c08e4c53b0382b6b61ce351b";
  Client httpClient = Client();
  String adminAddress = "0xe8AC78dFA2f511047d53EEee716e610651905d38";
  String privateKey="376f449d992a1347653e775dcdb278c8253503a951934925729abf4b28cef1c5";
  Web3Client ethClient;


  Future<DeployedContract> getContract() async {
//obtain our smart contract using rootbundle to access our json file
      ethClient=Web3Client(
          url,
          httpClient);
      print("GetContract()");
    String abiFile = await rootBundle.loadString("assets/ABI.json");


    String contractAddress = "0xf6ea057e2D8E4e79c0cbbd3674daE2A1CA563dEF";


    final contract = DeployedContract(ContractAbi.fromJson(abiFile, "Election"),
        EthereumAddress.fromHex(contractAddress));
    print(contract);
    return contract;
  }

  // fetches the address of the admin from the blockchain
  Future<String> getAdmin() async {

    return adminAddress;
  }
  Future<List<dynamic>> callFunction(String name,List<dynamic> args) async {
    final contract = await getContract();
    final function = contract.function(name);
    final result = await ethClient
        .call(contract: contract, function: function, params: args);
    return result;
  }

  //Fetches the count of registered candidates in the election
  Future<int> getCandidateCount() async {
    List<dynamic> response = await callFunction("getCandidateCount",[]);
    return response[0].toInt();
  }

  //Fetches the count of regsitered voters in the elction
  Future<int> getVoterCount() async {
    List<dynamic> response = await callFunction("getVoterCount",[]);
    return response[0].toInt();
  }

  //Fetches the current state of the election - CREATED, ONGOING or STOPPED
  Future<String> getElectionState() async {
    List<dynamic> response = await callFunction("checkState",[]);
    return response[0];
  }

  //Fetches a short description of the election
  Future<String> getDescription() async {
    List<dynamic> response = await callFunction("getDescription",[]);
    return response[0];
  }

  //Fetches the details of a candidate - ID, Name, Proposal
  Future<Candidate> getCandidate(int id) async {
    List<dynamic> response = await callFunction("displayCandidate",[id]);
    Map<String, dynamic> data={
      "id":response[0],
      "name":response[1],
      "proposal":response[2]
    };
    return Candidate.fromJson(data);
  }

  //Fetches the details of all the registered candidates
  Future<List<Candidate>> getAllCandidates() async {
    int count = await getCandidateCount();
    var list = List<int>.generate(count, (index) => index + 1);
    List<Candidate> result = [];
    
    await Future.wait(list.map((e) async {
      await callFunction("displayCandidate",[e]).then((value) {
        Map<String, dynamic> data={
          "id":value[0],
          "name":value[1],
          "proposal":value[2]
        };
        result.add(Candidate.fromJson(data));
      });
    }));
    return result;
  }

  //Fetches the details of a voter - ID, Address, DelegateAddress and Weight
  Future<Voter> getVoter(int id, String owner) async {
    //var response = await dioClient.get(url + "/getVoter/$id/$adminAddress");
      var ethAdd=EthereumAddress.fromHex(adminAddress);
    List<dynamic> response = await callFunction("getVoter",[id,ethAdd]);
    Map<String, dynamic> data={
      "id":response[0],
      "voterAddress":response[1],
      "weight":response[3],
      "delegate":response[2]
    };
    return Voter.fromJson(data);
  }

  //Fetches the details of all voters
  Future<List<Voter>> getAllVoters() async {
    int count = await getVoterCount();
    var ethAdd=EthereumAddress.fromHex(adminAddress);
    var list = List<int>.generate(count, (index) => index + 1);
    List<Voter> result = [];
    await Future.wait(list.map((e) async {
      await callFunction("getVoter",[e,ethAdd]).then((response) {
        Map<String, dynamic> data={
          "id":response[0],
          "voterAddress":response[1],
          "weight":response[3],
          "delegate":response[2]
        };
        result.add(Voter.fromJson(data));
      });
    }));
    print('hah');
    print(result.length);
    return result;
  }

  //Fetches the result of the candidate
  Future<Either<ErrorMessage, Candidate>> showCandidateResult(int id) async {
    try {
      //var response = await dioClient.get(url + "/showResults/$id");
      List<dynamic> response = await callFunction("showResults",[id]);
      Map<String, dynamic> data={
        "id":response[0],
        "name":response[1],
        "count":response[2]
      };
      return Right(Candidate.result(data));
    } catch (e) {
      return Left(ErrorMessage(
          message: "Cannot Process Request"));
    }
  }

  //Fetches the results of all the candidates
  Future<Either<ErrorMessage, List<Candidate>>> showResults() async {
    int count = await getCandidateCount();
    if (await getElectionState() != "CONCLUDED")
      return Left(ErrorMessage(message: "The election has not concluded yet."));
    var list = List<int>.generate(count, (index) => index + 1);
    List<Candidate> result = [];
    await Future.wait(list.map((e) async {
      await callFunction("showResults",[e]).then((response) {
        Map<String, dynamic> data={
          "id":response[0],
          "name":response[1],
          "count":response[2]
        };
        result.add(Candidate.result(data));
      });
    }));
    print(result.length);
    return Right(result);
  }

  //Returns the winner of the election
  Future<Either<ErrorMessage, Candidate>> getWinner() async {
    try {
      //var response = await dioClient.get(url + "/showWinner");
      List<dynamic> response = await callFunction("showWinner",[]);
      Map<String, dynamic> data={
        "id":response[1],
        "name":response[0],
        "count":response[2]
      };
      return Right(Candidate.winner(data));
    } catch (e) {
      return Left(ErrorMessage(
          message: "Cannot Process Request-2"));
    }
  }

  //Function to register a new candidate
  Future<Either<ErrorMessage, String>> addCandidate(
      String name, String proposal) async {
    Credentials key = EthPrivateKey.fromHex(privateKey);
    final contract = await getContract();
    var func=contract.function("addCandidate");

    try {
        var ethAdd=EthereumAddress.fromHex(adminAddress);
      var response=await ethClient.sendTransaction(
          key,
          Transaction.callContract(
              contract: contract, function: func, parameters: [name,proposal,ethAdd]),
          chainId: 4);


      return Right("Added Candidate");
    } catch (e) {
      return Left(ErrorMessage(
          message: "Cannot Add Candidate"));
    }
  }

  //Function to register a new voter
  Future<Either<ErrorMessage, String>> addVoter(String voter) async {
    Credentials key = EthPrivateKey.fromHex(privateKey);
    final contract = await getContract();
    var func=contract.function("addVoter");

    try {
        var ethAdd=EthereumAddress.fromHex(adminAddress);
        var ethVoter=EthereumAddress.fromHex(voter);
      var response = await ethClient.sendTransaction(
          key,
          Transaction.callContract(
              contract: contract, function: func, parameters: [ethVoter,ethAdd]),
          chainId: 4);
      return Right("Added Voter");


    } catch (e) {
        print(e);
     if (voter == adminAddress)
        return Left(ErrorMessage(message: "Admin Cannot be Voter"));
      else
        return Left(ErrorMessage(
            message: "Cannot Add Voter"));
    }
  }

  //Function to delegate your vote to someone else
  Future<Either<ErrorMessage, String>> delegateVoter(
      String delegate, String owner) async {
    print(delegate + "   " + owner);


    Credentials key = EthPrivateKey.fromHex(privateKey);
    final contract = await getContract();
    var func=contract.function("delegateVote");

    try {
        var ethowner=EthereumAddress.fromHex(owner);
        var ethDel=EthereumAddress.fromHex(delegate);
      var response = await ethClient.sendTransaction(
          key,
          Transaction.callContract(
              contract: contract, function: func, parameters: [ethDel,ethowner]),
          chainId: 4);


      return Right("Delegate Successful");
    } catch (e) {
        return Left(
            ErrorMessage(message: "Invalid arguments. Please try again."));

    }
  }

  //Function to endElection
  Future<Either<ErrorMessage, String>> endElection() async {
    Map<String, dynamic> map = {"owner": adminAddress};
    Credentials key = EthPrivateKey.fromHex(privateKey);
    final contract = await getContract();
    var func=contract.function("endElection");
    var ethAdd=EthereumAddress.fromHex(adminAddress);


    try {
      var response = await ethClient.sendTransaction(
          key,
          Transaction.callContract(
              contract: contract, function: func, parameters: [ethAdd]),
          chainId: 4);


      return Right("Election Ended!");
    } catch (e) {
      return Left(ErrorMessage(message: "Cannot Process Request.Try Again!"));
    }
  }

  Future<Either<ErrorMessage, String>> startElection() async {




    try {
        Credentials key = EthPrivateKey.fromHex(privateKey);
        final contract = await getContract();
        print("Start Elec");
        var func=contract.function("startElection");
        var ethAdd=EthereumAddress.fromHex(adminAddress);
      var response = await ethClient.sendTransaction(
          key,
          Transaction.callContract(
              contract: contract, function: func, parameters: [ethAdd]),
          fetchChainIdFromNetworkId: true,
          chainId: null);
        print("Start Elec-2");


      return Right("Election Started!");
    } catch (e) {
        print(e);
      return Left(ErrorMessage(message: "Cannot Process Request.Try Again!"));
    }

  }

  Future<Either<ErrorMessage, String>> vote(int id, String owner) async {
    Map<String, dynamic> map = {"owner": owner, "_ID": id};
    Credentials key = EthPrivateKey.fromHex(privateKey);
    final contract = await getContract();
    var func=contract.function("vote");


    try {
        var ethAdd=EthereumAddress.fromHex(adminAddress);
      var response = await ethClient.sendTransaction(
          key,
          Transaction.callContract(
              contract: contract, function: func, parameters: [ethAdd,id]),
          chainId: 4);


      return Right("Vote Submitted Successfully!");
    } catch (e) {
      return Left(ErrorMessage(message: "Cannot Submit Vote.Try Again!"));
    }
  }

  Future<Voter> getVoterProfile(String address) async {
    //var response = await dioClient.get(url + "/voterProfile/$address");
     var ethAdd= EthereumAddress.fromHex(address);
    List<dynamic> response = await callFunction("voterProfile",[ethAdd]);
    Map<String, dynamic> data={
      "id":response[0],
      "votedTowards":response[3],
      "weight":response[2],
      "weight":response[2],
      "delegate":response[1],
      "name":response[4]
    };
    return Voter.profileJson(data, address);
  }
}
