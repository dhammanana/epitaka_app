// Play Asset Delivery asset pack module — "core_db".
//
// Ships the two core databases (epitaka.db, dpd-dictionary.db) with the app
// via an INSTALL-TIME asset pack. Install-time packs are delivered as part of
// the AAB install (no runtime download — works fully offline) and are readable
// directly through the Android AssetManager.
//
// The .db files live in src/main/assets/ and are downloaded into place by the
// CI workflow (see .github/workflows/build_app.yml) because they are far too
// large to commit to git.
// NOTE: no version here — the com.android.asset-pack plugin ships with AGP
// (already on the build classpath via settings.gradle.kts). Declaring a
// version causes a resolution error ("already on the classpath with an
// unknown version").
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("core_db")
    dynamicDelivery {
        deliveryType.set("install-time")
    }
}
