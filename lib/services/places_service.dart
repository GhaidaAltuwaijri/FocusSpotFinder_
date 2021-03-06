import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:focus_spot_finder/data/data.dart';
import 'package:focus_spot_finder/models/geometry.dart';
import 'package:focus_spot_finder/models/location.dart';
import 'package:focus_spot_finder/models/place.dart';
import 'package:focus_spot_finder/models/place_opening_hours.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http; //to use the http request
import 'dart:convert' as convert;

import 'package:intl/intl.dart';

class PlacesService {
  Future<List<Place>> getPlaces(
      double lat, double lng, BitmapDescriptor icon) async {
    //get places from firebase
    List<Place> firebaseList = await getPlacesFirebase();

    //request for cafe
    var response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&type=cafe&rankby=distance&key=${Data().key}'));
    var json = convert.jsonDecode(response.body);

    //request for library
    var response2 = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&type=library&rankby=distance&key=${Data().key}'));
    var json2 = convert.jsonDecode(response2.body);

    //request for book_store
    var response3 = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&type=book_store&rankby=distance&key=${Data().key}'));
    var json3 = convert.jsonDecode(response3.body);

    //request for park
    var response4 = await http.get(Uri.parse('https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng&type=park&rankby=distance&key=${Data().key}'));
    var json4 = convert.jsonDecode(response4.body);

    //group all the responses and access the variable "results"
    //and map the responses into place objects in a list
    var jsonResults =
        json['results'] +
        json2['results'] +
        json3['results'] +
        json4['results'] as List;

    List<Place> list = jsonResults.map((place) => Place.fromJson(place, icon)).toList();


    List<String> blackList = [];

    // Get the black listed places from firebase and add the place id into the blackList list
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance.collection('googlePlaceBlackList').get();
    final allData = querySnapshot.docs.map((doc) => doc.data()).toList();
    for (int x = 0; x < allData.length; x++) {
      var noteInfo = querySnapshot.docs[x].data() as Map<String, dynamic>;
      blackList.add(noteInfo["PlaceId"]);
    }


    //loop over google place api list and remove the black listed places
    for (int i = 0; i < list.length; i++){
      for (int j = 0; j < blackList.length; j++) {
        if (list[i].placeId == blackList[j]){
          list.removeAt(i);
        }
      }
    }



    //add firebase list and return it
    list.addAll(firebaseList);
    return list;
  }

  //this method gets the places stored in firebase
  Future<List<Place>> getPlacesFirebase() async {

    List<Place> firebaseList = [];
    QuerySnapshot value = await FirebaseFirestore.instance.collection("newPlace").get();
    BitmapDescriptor iconMarker = await BitmapDescriptor.fromAssetImage(ImageConfiguration(devicePixelRatio: 1.0), 'assets/marker.png');

    //loop on the querysnapshot to access the docs
    for (int i = 0; i < value.size; i++) {
      var noteInfo = value.docs[i].data() as Map<String, dynamic>;
      String placeId = value.docs[i].id;
      String status = noteInfo['Status'];
      String name = noteInfo['Name'];
      String vicinity = noteInfo['Vicinity'];
      String types = noteInfo['Types'];
      final regExp = new RegExp(r"(\w+\\?\'?\w*\s?\w+)");
      var typesList = regExp
          .allMatches(types)
          .map((m) => m.group(0))
          .map((String item) => item.replaceAll(new RegExp(r'[\[\],]'), ''))
          .map((m) => m)
          .toList();

      double lat = noteInfo['Address']?.latitude ?? 0;
      double lng = noteInfo['Address']?.longitude ?? 0;
      String phoneNumber = noteInfo['Phone number'];
      String website = noteInfo['Website'];

      var photo;
      List<dynamic> photosList;
      if (noteInfo['Photo'] != null && noteInfo['Photo'] != "") {
        photo = noteInfo['Photo'].replaceAll('[', '').replaceAll(']', '');
        photosList = photo.split(',');
      }

      photo = photosList;

      String workingDays = "";
      List<dynamic> workingDaysList = [];
      bool openNow = false;

      if (noteInfo['WorkingHours'] != null && noteInfo['WorkingHours'] != "") {
        workingDays =
            noteInfo['WorkingHours'].replaceAll('[', '').replaceAll(']', '');
        workingDaysList = workingDays.split(',');

        var date = DateTime.now();
        var currentDay = DateFormat('EEEE').format(date);
        var currentTime = DateFormat('hh:mm a').format(date);
        var index;

        if (workingDaysList != null && workingDaysList.length == 7) {
          switch (currentDay) {
            case "Sunday":
              index = workingDaysList[0];
              break;
            case "Monday":
              index = workingDaysList[1];
              break;
            case "Tuesday":
              index = workingDaysList[2];
              break;
            case "Wednesday":
              index = workingDaysList[3];
              break;
            case "Thursday":
              index = workingDaysList[4];
              break;
            case "Friday":
              index = workingDaysList[5];
              break;
            case "Saturday":
              index = workingDaysList[6];
              break;
          }
        }

        const ss = ":";
        const es = "-";

        final startIndex = index.indexOf(ss);
        final endIndex = index.indexOf(es, startIndex + ss.length);
        final start2 = index.indexOf(es);

        final startTime = index
            .substring(startIndex + ss.length, endIndex)
            .replaceFirst(" ", "");
        final endTime = index
            .substring(
              start2 + ss.length,
            )
            .replaceFirst(" ", "");

        DateFormat dateFormat = new DateFormat.jm();

        DateTime open = dateFormat.parse(startTime);
        DateTime close = dateFormat.parse(endTime);
        DateTime now = dateFormat.parse(currentTime);

        if (open.isBefore(now) && close.isAfter(now)) {
          openNow = true;
        } else {
          openNow = false;
        }
      }

      String n = '';
      if (name != null) {
        n = name;
      }

      String v = '';
      if (vicinity != null) {
        v = vicinity;
      }

      String pn = '';
      if (phoneNumber != null) {
        pn = phoneNumber;
      }

      String w = '';
      if (website != null) {
        w = website;
      }

      List<dynamic> t = [];
      if (typesList != null) {
        t = typesList;
      }

      List<dynamic> wd = [];
      if (workingDaysList != null) {
        wd = workingDaysList;
      }

      PlaceOpeningHours poh =
          new PlaceOpeningHours(openNow: openNow, workingDays: wd);
      Location l = new Location(lat: lat, lng: lng);
      Geometry g = new Geometry(location: l);

      Place place = Place(
        placeId: placeId,
        geometry: g,
        name: n,
        vicinity: v,
        phoneNumber: pn,
        website: w,
        types: t,
        photos: photo,
        openingHours: poh,
        icon: iconMarker,
      );

      if(status == "Approved"){
        firebaseList.add(place);
      }
    }
    return firebaseList;
  }
}
