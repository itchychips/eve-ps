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
    public class EsiMarketGroup
    {
        public long MarketGroupId { get; set; }
        public string Description { get; set; } = "";
        public string Name { get; set; } = "";
        public long? ParentGroupId { get; set; }

        public override bool Equals(object? o)
        {
            return Equals(o as EsiMarketGroup);
        }

        public bool Equals(EsiMarketGroup? o)
        {
            return o != null &&
                MarketGroupId == o.MarketGroupId &&
                Description == o.Description &&
                Name == o.Name &&
                ParentGroupId == o.ParentGroupId;
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(MarketGroupId, Description, Name, ParentGroupId);
        }

    }
}
