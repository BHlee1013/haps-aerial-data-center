# GitHub and Zenodo publication steps for v1.0.0

1. Extract this package into a new folder and run:

   ```matlab
   restoredefaultpath;
   rehash toolboxcache;
   clear functions;
   setup_haps;
   rc = verify_release_candidate;
   disp(rc.summary);
   rc.passed
   rc.publication_ready
   ```

   Expected: both values are `true`.

2. Use repository `https://github.com/BHlee1013/haps-aerial-data-center` and commit the contents of the `haps-aerial-data-center/` directory.

3. Create Git tag **`v1.0.0`** and GitHub Release **`v1.0.0`**. `RELEASE_NOTES.md` is the release-note starting point.

4. Enable/connect the repository in Zenodo and archive the GitHub `v1.0.0` release.

5. Zenodo will issue the archival DOI. Add that actual DOI to the manuscript Data/Code Availability statements. Optionally add it to README/CITATION in a follow-up commit or patch release.

Do not fabricate a DOI and do not rewrite an already archived `v1.0.0` tag solely to insert the DOI.
