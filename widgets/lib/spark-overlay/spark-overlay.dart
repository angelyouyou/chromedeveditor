// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.overlay;

import 'dart:async';
import 'dart:html';
import 'package:polymer/polymer.dart';

import '../common/widget.dart';

// Ported from Polymer Javascript to Dart code.
@CustomTag("spark-overlay")
class SparkOverlay extends Widget {
  // TODO(sorvell): need keyhelper component.
  static final int ESCAPE_KEY = 27;

  // track overlays for z-index and focus managemant
  static List overlays = [];
  static void trackOverlays(inOverlay) {
    if (inOverlay.opened) {
      var z0 = currentOverlayZ();
      overlays.add(inOverlay);
      var z1 = currentOverlayZ();
      if (z0 != null && z1 != null && z1 <= z0) {
        applyOverlayZ(inOverlay, z0);
      }
    } else {
      var i = overlays.indexOf(inOverlay);
      if (i >= 0) {
        overlays.removeAt(i);
        setZ(inOverlay, null);
      }
    }
  }

  static void applyOverlayZ(inOverlay, inAboveZ) {
    setZ(inOverlay, inAboveZ + 2);
  }

  static void setZ(inNode, inZ) {
    inNode.style.zIndex = "$inZ";
  }

  static currentOverlay() {
    return overlays.isNotEmpty ? overlays.last : null;
  }

  static int DEFAULT_Z = 10;

  static currentOverlayZ() {
    var z = DEFAULT_Z;
    var current = currentOverlay();
    if (current != null) {
      var z1 = current.getComputedStyle().zIndex;
      z = int.parse(z1, onError: (source) { });
    }
    return z;
  }

  static void focusOverlay() {
    var current = currentOverlay();
    if (current != null) {
      current.applyFocus();
    }
  }

  SparkOverlay.created(): super.created();

  /**
   * Set opened to true to show an overlay and to false to hide it.
   * A spark-overlay may be made intially opened by setting its opened
   * attribute.
   */
  @published bool opened = false;

  /**
   * By default an overlay will close automatically if the user taps outside
   * it or presses the escape key. Disable this behavior by setting the
   * autoCloseDisabled property to true.
   */
  @published bool autoCloseDisabled = false;

  // TODO(terry): Should be tap when PointerEvents are supported.
  static const String captureEventType = 'mousedown';
  Timer autoCloseTask = null;

  void ready() {
    style.visibility = "visible";
    if (tabIndex == null) {
      tabIndex = -1;
    }
    attributes['touch-action'] = 'none';
  }

  /// Toggle the opened state of the overlay.
  void toggle() {
    opened = !opened;
  }

  void openedChanged() {
    renderOpened();
    trackOverlays(this);
    if (!autoCloseDisabled) {
      enableCaptureHandler(opened);
    }
    enableResizeHandler(opened);
    asyncFire('opened', detail: opened);
  }

  void enableResizeHandler(inEnable) {
    if (inEnable) {
      window.addEventListener('resize', resizeHandler);
    } else {
      window.removeEventListener('resize', resizeHandler);
    }
  }

  void enableCaptureHandler(inEnable) {
    // TODO(terry): Need to use overlay docfrag document doesn't map to that.
    //              However, we should use getShadowRoot or lightdom or the
    //              event.path when those work we should be able to use
    //              var doc = getShadowRoot('spark-overlay');
    var doc = document;
    if (inEnable) {
      doc.addEventListener(captureEventType, captureHandler, true);
    } else {
      doc.removeEventListener(captureEventType, captureHandler, true);
    }
  }

  getFocusNode() {
    var focus = querySelector('[autofocus]');
    return (focus != null) ? focus : this;
  }

  // TODO(sorvell): nodes stay focused when they become un-focusable due to
  // an ancestory becoming display: none; file bug.
  void applyFocus() {
    var focusNode = getFocusNode();
    if (opened) {
      focusNode.focus();
    } else {
      focusNode.blur();
      focusOverlay();
    }
  }

  void renderOpened() {
    classes.remove('closing');
    classes.add('revealed');
    // continue styling after delay so display state can change without
    // aborting transitions
    Timer.run(() { continueRenderOpened(); });
//    asyncMethod('continueRenderOpened');
  }

  void continueRenderOpened() {
    classes.toggle('opened', opened);
    classes.toggle('closing', !opened);
//    this.animating = this.asyncMethod('completeOpening', null, this.timeout);
  }

  void completeOpening() {
//    clearTimeout(this.animating);
    classes.remove('closing');
    classes.toggle('revealed', opened);
    applyFocus();
  }

  void openedAnimationEnd(AnimationEvent e) {
    if (!opened) {
      classes.remove('animation');
    }
    // same steps as when a transition ends
    openedTransitionEnd(e);
  }

  void openedTransitionEnd(Event e) {
    // TODO(sorvell): Necessary due to
    // https://bugs.webkit.org/show_bug.cgi?id=107892
    // Remove when that bug is addressed.
    if (e.target == this) {
      completeOpening();
      e.stopImmediatePropagation();
      e.preventDefault();
    }
  }

  void openedAnimationStart(AnimationEvent e) {
    classes.add('animation');
    e.stopImmediatePropagation();
    e.preventDefault();
  }

  void tapHandler(MouseEvent e) {
    Element target = e.target;
    if (target != null && target.attributes.containsKey('overlay-toggle')) {
      toggle();
      if (target.attributes.containsKey('primary')) {
        asyncFire('commit');
      }
    } else if (autoCloseTask != null) {
      autoCloseTask.cancel();
      autoCloseTask = null;
    }
  }

  // TODO(sorvell): This approach will not work with modal. For this we need a
  // scrim.
  void captureHandler(MouseEvent e) {
    // TODO(terry): Hack to work around lightdom or event.path not yet working.
    if (!autoCloseDisabled && !pointInOverlay(this, e.client)) {
      // TODO(terry): How to cancel the event e.cancelable = true;
      e.stopImmediatePropagation();
      e.preventDefault();

      autoCloseTask = new Timer(Duration.ZERO, () { opened = false; });
    }
  }

  bool pointInOverlay(SparkOverlay overlay, Point xyGlobal) {
    return overlay.offset.containsPoint(xyGlobal);
  }


  void keydownHandler(KeyboardEvent e) {
    if (!autoCloseDisabled && (e.keyCode == ESCAPE_KEY)) {
      this.opened = false;
      e.stopImmediatePropagation();
      e.preventDefault();
    }
  }

  /**
   * Extensions of spark-overlay should implement the resizeHandler
   * method to adjust the size and position of the overlay when the
   * browser window resizes.
   */
  void resizeHandler(e) {
  }
}
