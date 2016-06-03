/**
 * solidbc.d
 *
 * Author: Rowan G. and Peter J.
 */

module solidbc;

import std.json;
import std.conv;

import geom;
import json_helper;
import solid_boundary_interface_effect;
import solid_boundary_flux_effect;
import ssolidblock;
import globaldata;

SolidBoundaryCondition makeSolidBCFromJson(JSONValue jsonData, int blk_id, int boundary,
					   size_t nicell, size_t njcell, size_t nkcell)
{
    auto setsFluxDirectly = getJSONbool(jsonData, "sets_flux_directly", false);
    auto newBC = new SolidBoundaryCondition(blk_id, boundary, setsFluxDirectly);
    newBC.label = getJSONstring(jsonData, "label", "");
    newBC.type = getJSONstring(jsonData, "type", "");
    newBC.group = getJSONstring(jsonData, "group", "");
    // Assemble list of preSpatialDerivAction effects
    auto preSpatialDerivActionList = jsonData["pre_spatial_deriv_action"].array;
    foreach ( jsonObj; preSpatialDerivActionList ) {
	newBC.preSpatialDerivAction ~= makeSolidBIEfromJson(jsonObj, blk_id, boundary);
    }
    return newBC;
}

class SolidBoundaryCondition {
public:
    SSolidBlock blk;
    int whichBoundary;
    bool setsFluxDirectly;
    // We may have a label for this specific boundary.
    string label;
    // We have a symbolic name for the type of boundary condition
    // when thinking about the flow problem conceptually. 
    string type;
    // Sometimes it is convenient to think of individual boundaries
    // grouped together.
    string group;
    SolidBoundaryInterfaceEffect[] preSpatialDerivAction;
    //SolidBoundaryFluxEffect[] postFluxAction;

    this(int blkId, int boundary, bool _setsFluxDirectly)
    {
	blk = solidBlocks[blkId];
	whichBoundary = boundary;
	setsFluxDirectly = _setsFluxDirectly;
    }

    final void applyPreSpatialDerivAction(double t, int tLevel)
    {
	foreach ( sie; preSpatialDerivAction ) sie.apply(t, tLevel);
    }

    final void applyPostFluxAction(double t, int tLevel)
    {
	//foreach ( sfe; postFluxAction ) sfe.apply(t, tLevel);
    }

}
