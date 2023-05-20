library google_places_flutter;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_places_flutter/model/place_details.dart';
import 'package:google_places_flutter/model/prediction.dart';

import 'package:rxdart/subjects.dart';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

class GooglePlaceAutoCompleteTextField extends StatefulWidget {
  InputDecoration inputDecoration;
  ItemClick? itmClick;
  GetPlaceDetailswWithLatLng? getPlaceDetailWithLatLng;
  bool isLatLngRequired = true;
  double? lat;
  double? lng;
  double? radius;
  List<String>? types;
  TextStyle textStyle;
  String googleAPIKey;
  int debounceTime = 600;
  bool enabled;
  FocusNode? focusNode;
  Function(String)? customTextChanged;
  List<String>? countries = [];
  TextEditingController textEditingController = TextEditingController();

  GooglePlaceAutoCompleteTextField({
    required this.textEditingController,
    required this.googleAPIKey,
    this.debounceTime: 600,
    this.inputDecoration: const InputDecoration(),
    this.itmClick,
    this.customTextChanged,
    this.lat,
    this.lng,
    this.radius,
    this.types,
    this.focusNode,
    this.enabled = true,
    this.isLatLngRequired = true,
    this.textStyle: const TextStyle(),
    this.countries,
    this.getPlaceDetailWithLatLng,
  });

  @override
  _GooglePlaceAutoCompleteTextFieldState createState() =>
      _GooglePlaceAutoCompleteTextFieldState();
}

class _GooglePlaceAutoCompleteTextFieldState
    extends State<GooglePlaceAutoCompleteTextField> {
  final subject = new PublishSubject<String>();
  OverlayEntry? _overlayEntry;
  OverlayEntry? _overlayLoadingEntry;
  List<Prediction> alPredictions = [];

  TextEditingController controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  bool isSearched = false;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        decoration: widget.inputDecoration,
        style: widget.textStyle,
        controller: widget.textEditingController,
        onChanged: (string) {
          if (widget.customTextChanged != null)
            widget.customTextChanged!(string);
          subject.add(string);
        },
      ),
    );
  }

  getLocation(String text) async {
    this._overlayLoadingEntry = null;
    this._overlayLoadingEntry = this._createLoadingOverlayEntry();
    Overlay.of(context)!.insert(this._overlayLoadingEntry!);

    Dio dio = new Dio();
    String url =
        "https://maps.googleapis.com/maps/api/place/${widget.radius != null? "nearbysearch" : "autocomplete"}/json?input=$text&key=${widget
        .googleAPIKey}";

    if (widget.lat != null && widget.lng != null) {
      url = url + "&location=${widget.lat},${widget.lng}";
    }

    if (widget.radius != null) {
      url = url + "&radius=${widget.radius}";
    }

    if (widget.radius == null && widget.types != null) {
      url = url + "&types=${widget.types!.join("|")}";
    }

    if (widget.countries != null) {
      // in

      for (int i = 0; i < widget.countries!.length; i++) {
        String country = widget.countries![i];

        if (i == 0) {
          url = url + "&components=country:$country";
        } else {
          url = url + "|" + "country:" + country;
        }
      }
    }

    Response response = await dio.get(url);
    PlacesAutocompleteResponse subscriptionResponse =
    PlacesAutocompleteResponse.fromJson(response.data);
    this._overlayLoadingEntry!.remove();
    if (text.length == 0) {
      alPredictions.clear();
      this._overlayEntry!.remove();
      return;
    }

    isSearched = false;
    if (subscriptionResponse.predictions!.length > 0) {
      alPredictions.clear();
      for(Prediction prediction in subscriptionResponse.predictions!) {
        if(prediction.types?.any((element) => widget.types?.contains(element)??true) ?? false){
          alPredictions.add(prediction);
        }
      }
    }

    //if (this._overlayEntry == null)
    if(this._overlayEntry!=null) {
      this._overlayEntry!.remove();
    }
    this._overlayEntry = null;
    this._overlayEntry = this._createOverlayEntry();
    Overlay.of(context)!.insert(this._overlayEntry!);
    //   this._overlayEntry.markNeedsBuild();
  }

  @override
  void initState() {
    subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(textChanged);
  }

  textChanged(String text) async {
    getLocation(text);
  }

  OverlayEntry? _createLoadingOverlayEntry() {
    if (context != null && context.findRenderObject() != null) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
          builder: (context) =>
              Positioned(
                  left: offset.dx,
                  top: size.height + offset.dy,
                  width: size.width,
                  child: CompositedTransformFollower(
                      showWhenUnlinked: false,
                      link: this._layerLink,
                      offset: Offset(0.0, size.height + 5.0),
                      child: Material(
                          elevation: 1.0,
                          child: Center(
                            child: Container(
                                width: 20,
                                height: 20,
                                margin: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 10),
                                child: const CircularProgressIndicator()),
                          )))));
    }
  }

  OverlayEntry? _createOverlayEntry() {
    if (context != null && context.findRenderObject() != null) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
          builder: (context) =>
              Positioned(
                left: offset.dx,
                top: size.height + offset.dy,
                width: size.width,
                bottom: MediaQuery
                    .of(context)
                    .viewInsets
                    .bottom,
                child: CompositedTransformFollower(
                  showWhenUnlinked: false,
                  link: this._layerLink,
                  offset: Offset(0.0, size.height + 5.0),
                  child: Material(
                      elevation: 1.0,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: alPredictions.length,
                        separatorBuilder: (context, index) => Divider(),
                        itemBuilder: (BuildContext context, int index) {
                          String desc = alPredictions[index].description!;
                          int descLength = desc
                              .split(",")
                              .length;
                          return ListTile(
                              onTap: () {
                                if (index < alPredictions.length) {
                                  widget.itmClick!(alPredictions[index]);
                                  if (!widget.isLatLngRequired) return;

                                  getPlaceDetailsFromPlaceId(
                                      alPredictions[index]);

                                  this._overlayEntry!.remove();
                                  removeOverlay();
                                }
                              },
                              leading: Icon(Icons.location_on),
                              horizontalTitleGap: 8,
                              subtitle: Text(
                                desc
                                    .split(",")
                                    .sublist(1, descLength < 4 ? descLength : 4)
                                    .join(", "),
                                style: TextStyle(
                                    color: Theme
                                        .of(context)
                                        .disabledColor
                                        .withAlpha(150)),
                              ),
                              title: Text(desc
                                  .split(",")
                                  .first));
                        },
                      )),
                ),
              ));
    }
  }

  removeOverlay() {
    alPredictions.clear();
    // this._overlayEntry = this._createOverlayEntry();
    this._overlayEntry!.remove();
    if (context != null) {
      Overlay.of(context)!.insert(this._overlayEntry!);
      this._overlayEntry!.markNeedsBuild();
    }
    return;
  }

  Future<Response?> getPlaceDetailsFromPlaceId(Prediction prediction) async {
    //String key = GlobalConfiguration().getString('google_maps_key');

    var url =
        "https://maps.googleapis.com/maps/api/place/details/json?placeid=${prediction
        .placeId}&key=${widget.googleAPIKey}";
    Response response = await Dio().get(
      url,
    );

    PlaceDetails placeDetails = PlaceDetails.fromJson(response.data);

    prediction.lat = placeDetails.result!.geometry!.location!.lat.toString();
    prediction.lng = placeDetails.result!.geometry!.location!.lng.toString();

    widget.getPlaceDetailWithLatLng!(prediction);

//    prediction.latLng = new LatLng(
//        placeDetails.result.geometry.location.lat,
//        placeDetails.result.geometry.location.lng);
  }
}

PlacesAutocompleteResponse parseResponse(Map responseBody) {
  return PlacesAutocompleteResponse.fromJson(
      responseBody as Map<String, dynamic>);
}

PlaceDetails parsePlaceDetailMap(Map responseBody) {
  return PlaceDetails.fromJson(responseBody as Map<String, dynamic>);
}

typedef ItemClick = void Function(Prediction postalCodeResponse);
typedef GetPlaceDetailswWithLatLng = void Function(
    Prediction postalCodeResponse);
