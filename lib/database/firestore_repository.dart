import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:e_vote/features/auth/data/user_repository.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class FirestoreRepository {
  static final firestoreRepository = FirebaseFirestore.instance;
  /*The collection that will hold all the data of the users is called 'users'.
  Each document under the 'users' collection will reference a user.
  */

  //used to reference the collection of users
  final CollectionReference ref = firestoreRepository.collection('users');
  /*Function to create a document for a new user (called when a new user registers)
  ENSURE that EMAIL IS UNIQUE (If not, add UID field)
  */
  void createNewUser(String email) {
    print("USER CREATED");
    var privateKey = generateNewPrivateKey(Random.secure());

    var uid = ref.add(<String, dynamic>{
      "email": email,
      "address": EthereumAddress.fromPublicKey(privateKeyToPublic(privateKey))
          .toString(),
      "admin": false,
      "hasVoted": false,
      "delegate": null
    });
  }

  //Function to check whether a user is admin or voter/candidate
  Future<bool> isVoter(String email) async {
    print("VOTER----->");
    final querySnapshot =
        await ref.where('email', isEqualTo: email).get();
    var data=querySnapshot.docs[0].data() as Map<String, dynamic>;
    if (data['admin'] == null ||
        data['admin'] == false)
      return true;
    else
      return false;
  }

  Future<String> getVoterAddress(String email) async {
    var doc = await ref.where("email", isEqualTo: email).get();
    var dt=doc.docs[0].data() as Map<String, dynamic>;
    return dt["address"];
  }
}