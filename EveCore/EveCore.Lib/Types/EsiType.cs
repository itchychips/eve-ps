// This file is part of Eve-PS.
//
// Eve-PS is free software: you can redistribute it and/or modify it under the
// terms of the GNU Affero Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// Eve-PS is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE. See the GNU Affero Public License for more details.
//
// You should have received a copy of the GNU Affero Public License along with
// Eve-PS. If not, see <https://www.gnu.org/licenses/>.
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EveCore.Lib.Types
{
    public class EsiType
    {
        public long TypeId { get; set; }
        public double? Capacity { get; set; }
        public string Description { get; set; } = "";
        public long? GraphicId { get; set; }
        public long GroupId { get; set; }
        public long? IconId { get; set; }
        public long? MarketGroupId { get; set; }
        public double? Mass { get; set; }
        public string Name { get; set; } = "";
        public double? PackagedVolume { get; set; }
        public long? PortionSize { get; set; }
        public bool Published { get; set; }
        public double? Radius { get; set; }
        public double? Volume { get; set; }

        public override bool Equals(object? o)
        {
            return Equals(o as EsiType);
        }

        public bool Equals(EsiType? o)
        {

            return o != null && TypeId == o.TypeId &&
                Capacity == o.Capacity &&
                Description == o.Description &&
                GraphicId == o.GraphicId &&
                GroupId == o.GroupId &&
                IconId == o.IconId &&
                MarketGroupId == o.MarketGroupId &&
                Mass == o.Mass &&
                Name == o.Name &&
                PackagedVolume == o.PackagedVolume &&
                PortionSize == o.PortionSize &&
                Published == o.Published &&
                Radius == o.Radius &&
                Volume == o.Volume;
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(HashCode.Combine(TypeId, Capacity, Description, GraphicId,
            GroupId, IconId, MarketGroupId), HashCode.Combine(Mass, Name, PackagedVolume,
            PortionSize, Published, Radius, Volume));
        }
    }
}
