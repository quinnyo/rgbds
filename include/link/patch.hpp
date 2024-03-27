/* SPDX-License-Identifier: MIT */

#ifndef RGBDS_LINK_PATCH_H
#define RGBDS_LINK_PATCH_H

/*
 * Checks all assertions
 * @return true if assertion failed
 */
void patch_CheckAssertions();

/*
 * Applies all SECTIONs' patches to them
 */
void patch_ApplyPatches();

#endif // RGBDS_LINK_PATCH_H
