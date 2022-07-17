using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EveCore.Lib.Types
{
    public class EsiCategory
    {
        public long CategoryId { get; set; }
        public string? Name { get; set; }
        public bool? Published { get; set; }
    }
}
